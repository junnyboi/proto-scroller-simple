import { spawn } from "node:child_process";
import { mkdir, rm, symlink, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SCRIPT_DIR, "..");
const ARTIFACT_DIR = path.join(ROOT, "game", "artifacts", "browser");
const REPORT_PATH = path.join(ARTIFACT_DIR, "gameplay-smoke.json");
const SCREENSHOT_PATH = path.join(ARTIFACT_DIR, "gameplay-smoke.png");
const TITLE_LANDSCAPE_SCREENSHOT_PATH = path.join(
  ARTIFACT_DIR,
  "title-video-landscape.png"
);
const TITLE_PORTRAIT_SCREENSHOT_PATH = path.join(
  ARTIFACT_DIR,
  "title-video-portrait.png"
);
const TITLE_FADE_SCREENSHOT_PATH = path.join(
  ARTIFACT_DIR,
  "title-fade-transition.png"
);
const DEATH_FADE_SCREENSHOT_PATH = path.join(
  ARTIFACT_DIR,
  "death-fade-transition.png"
);
const DEATH_SUMMARY_SCREENSHOT_PATH = path.join(
  ARTIFACT_DIR,
  "death-summary.png"
);
const RETURN_TITLE_FADE_SCREENSHOT_PATH = path.join(
  ARTIFACT_DIR,
  "return-title-fade-transition.png"
);
const FAILURE_SCREENSHOT_PATH = path.join(
  ARTIFACT_DIR,
  "gameplay-smoke-failure.png"
);
const SMOKE_ENGINE_DIR = path.join(ROOT, "client", "public", "remote-engine");
const PORT = Number(process.env.PROTO_SCROLLER_SMOKE_PORT ?? 4173);
const BASE_URL = `http://127.0.0.1:${PORT}`;
const CHROMIUM_PATH = process.env.CHROMIUM_PATH ?? "/usr/bin/chromium";
const EXPECTED_PHASES = [
  "ready",
  "charge_started",
  "charge_progress",
  "charge_released",
  "east_walk_ok",
  "pass",
  "defeat_requested",
];

await mkdir(ARTIFACT_DIR, { recursive: true });
await rm(SMOKE_ENGINE_DIR, { recursive: true, force: true });
await mkdir(SMOKE_ENGINE_DIR, { recursive: true });
await symlink(
  path.join(ROOT, "client", "public", "game", "game.wasm"),
  path.join(SMOKE_ENGINE_DIR, "smoke-engine.wasm")
);

const serverOutput = [];
const browserErrors = [];
const requestFailures = [];
const httpErrors = [];
const instrumentedPages = new WeakSet();
let server;
let browser;
let page;
let report = {
  status: "FAIL",
  url: `${BASE_URL}/?localGame=1&splitWorklets=1&webSmoke=1`,
  phases: [],
  audioContextStates: [],
  browserErrors,
  requestFailures,
  httpErrors,
  workletModules: [],
  titleVideo: null,
  portraitTitleVideo: null,
  titleSourceSwitching: null,
  standaloneTitleMusicSync: null,
  standaloneShellLayout: null,
  titleMusicFallback: null,
  titleTransition: null,
  deathTransition: null,
  returnTitleTransition: null,
};

try {
  server = spawn(
    "pnpm",
    [
      "exec",
      "vite",
      "--host",
      "127.0.0.1",
      "--port",
      String(PORT),
      "--strictPort",
    ],
    {
      cwd: ROOT,
      env: { ...process.env, BROWSER: "none" },
      detached: true,
      stdio: ["ignore", "pipe", "pipe"],
    }
  );
  server.stdout.on("data", chunk => serverOutput.push(chunk.toString()));
  server.stderr.on("data", chunk => serverOutput.push(chunk.toString()));
  await waitForHttp(`${BASE_URL}/`, 30_000, server);

  browser = await chromium.launch({
    executablePath: CHROMIUM_PATH,
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu-compositing",
      "--use-angle=swiftshader-webgl",
    ],
  });
  const context = await browser.newContext({
    viewport: { width: 720, height: 1280 },
  });
  await context.addInitScript(() => {
    const NativeAudioContext = window.AudioContext ?? window.webkitAudioContext;
    window.__PROTO_SCROLLER_AUDIO_CONTEXTS__ = [];
    window.__PROTO_SCROLLER_WORKLET_MODULES__ = [];
    window.__PROTO_SCROLLER_AUDIO_BUFFER_STARTS__ = [];
    const sourcePrototype = window.AudioBufferSourceNode?.prototype;
    if (sourcePrototype) {
      const nativeStart = sourcePrototype.start;
      sourcePrototype.start = function (when = 0, offset = 0, duration) {
        window.__PROTO_SCROLLER_AUDIO_BUFFER_STARTS__.push({
          hasBuffer: this.buffer instanceof AudioBuffer,
          length: this.buffer?.length ?? 0,
          when,
        });
        if (duration === undefined) nativeStart.call(this, when, offset);
        else nativeStart.call(this, when, offset, duration);
      };
    }
    if (!NativeAudioContext) return;
    const TrackingAudioContext = new Proxy(NativeAudioContext, {
      construct(Target, args) {
        const audioContext = Reflect.construct(Target, args);
        window.__PROTO_SCROLLER_AUDIO_CONTEXTS__.push(audioContext);
        const nativeAddModule = audioContext.audioWorklet?.addModule?.bind(
          audioContext.audioWorklet
        );
        if (nativeAddModule) {
          audioContext.audioWorklet.addModule = async (url, options) => {
            const entry = {
              url: new URL(String(url), window.location.href).href,
              state: "pending",
            };
            window.__PROTO_SCROLLER_WORKLET_MODULES__.push(entry);
            try {
              await nativeAddModule(url, options);
              entry.state = "fulfilled";
            } catch (error) {
              entry.state = "rejected";
              entry.error =
                error instanceof Error ? error.message : String(error);
              throw error;
            }
          };
        }
        return audioContext;
      },
    });
    window.AudioContext = TrackingAudioContext;
    if (window.webkitAudioContext) {
      window.webkitAudioContext = TrackingAudioContext;
    }
  });
  context.on("page", attachPageHandlers);
  page = await context.newPage();
  attachPageHandlers(page);

  await page.goto(report.url, {
    waitUntil: "domcontentloaded",
    timeout: 30_000,
  });
  await waitForTitleSource(page, "title-loop-portrait.mp4", 30_000);
  const landscapeInitialSource = await titleSourceSnapshot(page);
  await page.setViewportSize({ width: 1280, height: 720 });
  await waitForTitleSource(page, "title-loop-landscape.mp4", 30_000);
  const landscapePreActivationSource = await titleSourceSnapshot(page);
  await page.waitForFunction(
    () =>
      document.querySelector("canvas.is-ready") &&
      !document.getElementById("runtime-state"),
    undefined,
    { timeout: 120_000 }
  );
  await page.waitForFunction(
    () => {
      const video = document.getElementById("title-video-backdrop");
      return (
        video instanceof HTMLVideoElement &&
        document.body.classList.contains("title-backdrop-active") &&
        video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA &&
        !video.paused &&
        video.currentTime > 0
      );
    },
    undefined,
    { timeout: 30_000 }
  );
  const titleVideoStart = await page.evaluate(() => {
    const video = document.getElementById("title-video-backdrop");
    if (!(video instanceof HTMLVideoElement)) return null;
    return {
      currentSrc: video.currentSrc,
      currentTime: video.currentTime,
      duration: video.duration,
      loop: video.loop,
      muted: video.muted,
      paused: video.paused,
      readyState: video.readyState,
      videoHeight: video.videoHeight,
      videoWidth: video.videoWidth,
    };
  });
  await page.waitForTimeout(350);
  const titleVideoAdvancedTime = await page.evaluate(() => {
    const video = document.getElementById("title-video-backdrop");
    return video instanceof HTMLVideoElement ? video.currentTime : 0;
  });
  if (
    !titleVideoStart ||
    !titleVideoStart.currentSrc.endsWith(
      "/title-video/title-loop-landscape.mp4"
    ) ||
    titleVideoStart.duration < 7.9 ||
    titleVideoStart.duration > 8.1 ||
    !titleVideoStart.loop ||
    !titleVideoStart.muted ||
    titleVideoStart.paused ||
    titleVideoStart.videoWidth !== 1280 ||
    titleVideoStart.videoHeight !== 720 ||
    titleVideoAdvancedTime <= titleVideoStart.currentTime
  ) {
    throw new Error(
      `title video contract failed: ${JSON.stringify({ titleVideoStart, titleVideoAdvancedTime })}`
    );
  }
  await page.screenshot({ path: TITLE_LANDSCAPE_SCREENSHOT_PATH });
  await page.evaluate(() => {
    window.__PROTO_SCROLLER_HOLD_TITLE_TRANSITION__ = true;
  });
  const titleTransitionStartedAt = Date.now();
  await page.keyboard.press("Enter");
  await page.waitForFunction(
    () => window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__?.orientation === "landscape",
    undefined,
    { timeout: 5_000 }
  );
  await page.evaluate(() => {
    window.__PROTO_SCROLLER_LOCKED_SOURCE_SAMPLES__ = [];
    window.__PROTO_SCROLLER_LOCKED_SOURCE_TIMER__ = window.setInterval(() => {
      const video = document.getElementById("title-video-backdrop");
      window.__PROTO_SCROLLER_LOCKED_SOURCE_SAMPLES__.push(video?.currentSrc ?? "");
    }, 25);
  });
  await page.setViewportSize({ width: 720, height: 1280 });
  await page.waitForTimeout(250);
  const landscapePostActivationSource = await titleSourceSnapshot(page);
  if (!landscapePostActivationSource.currentSrc.endsWith("title-loop-landscape.mp4")) {
    throw new Error(
      `landscape source changed after activation: ${JSON.stringify(landscapePostActivationSource)}`
    );
  }
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.waitForFunction(
    () => {
      const sync = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__;
      return sync?.committed === true;
    },
    undefined,
    { timeout: 12_000 }
  );
  const landscapeTitleMusicSync = await page.evaluate(() => ({
    ...window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__,
  }));
  if (
    landscapeTitleMusicSync.orientation !== "landscape" ||
    !landscapeTitleMusicSync.source.endsWith("title-loop-landscape.mp4") ||
    Math.abs(landscapeTitleMusicSync.impactSeconds - 88 / 24) > 0.000_001 ||
    landscapeTitleMusicSync.trusted !== true ||
    landscapeTitleMusicSync.sourceKind !== "AudioBufferSourceNode/non-silent" ||
    Math.abs(landscapeTitleMusicSync.renderedSyncError) > 1 / 24
  ) {
    throw new Error(
      `landscape title beat sync failed: ${JSON.stringify(landscapeTitleMusicSync)}`
    );
  }
  await page.evaluate(() =>
    new Promise(resolve => {
      const video = document.getElementById("title-video-backdrop");
      if (!(video instanceof HTMLVideoElement)) return resolve();
      const observe = (_now, metadata) => {
        if (metadata.mediaTime >= 88 / 24) resolve();
        else video.requestVideoFrameCallback(observe);
      };
      video.requestVideoFrameCallback(observe);
    })
  );
  await page.screenshot({ path: TITLE_LANDSCAPE_SCREENSHOT_PATH });
  await page.waitForFunction(
    () => window.__PROTO_SCROLLER_TITLE_TRANSITION__?.phase === "black_ready",
    undefined,
    { timeout: 10_000 }
  );
  const titleTransitionCapture = await page.evaluate(() => ({
    elapsedMs: Date.now(),
    telemetry: window.__PROTO_SCROLLER_TITLE_TRANSITION__,
  }));
  await page.screenshot({ path: TITLE_FADE_SCREENSHOT_PATH });
  await page.evaluate(() => {
    window.__PROTO_SCROLLER_HOLD_TITLE_TRANSITION__ = false;
  });
  await page.waitForFunction(
    () => window.__PROTO_SCROLLER_TITLE_TRANSITION__?.phase === "complete",
    undefined,
    { timeout: 5_000 }
  );
  const titleTransition = await page.evaluate(() => ({
    ...window.__PROTO_SCROLLER_TITLE_TRANSITION__,
  }));
  titleTransition.durationMs = Date.now() - titleTransitionStartedAt;
  titleTransition.capturePhase = titleTransitionCapture.telemetry?.phase;
  titleTransition.captureElapsedMs =
    titleTransitionCapture.elapsedMs - titleTransitionStartedAt;
  const titleTransitionPhases = titleTransition.phases?.map(
    entry => entry.phase
  );
  const fadeBlackPhase = titleTransition.phases?.find(
    entry => entry.phase === "black"
  );
  const fadeInPhase = titleTransition.phases?.find(
    entry => entry.phase === "fade_in"
  );
  const fadeCompletePhase = titleTransition.phases?.find(
    entry => entry.phase === "complete"
  );
  if (
    JSON.stringify(titleTransitionPhases) !==
      JSON.stringify([
        "fade_out",
        "black",
        "black_ready",
        "fade_in",
        "complete",
      ]) ||
    titleTransition.kind !== "start_game" ||
    titleTransition.boomCount !== 1 ||
    fadeBlackPhase?.boomCount !== 1 ||
    fadeBlackPhase?.overlayAlpha < 0.999 ||
    titleTransition.capturePhase !== "black_ready" ||
    !fadeBlackPhase ||
    fadeBlackPhase.elapsedMs < 250 ||
    fadeBlackPhase.elapsedMs > 1_000 ||
    !fadeInPhase ||
    fadeInPhase.elapsedMs < fadeBlackPhase.elapsedMs ||
    fadeInPhase.elapsedMs - fadeBlackPhase.elapsedMs > 3_000 ||
	    !fadeCompletePhase ||
	    fadeCompletePhase.elapsedMs - fadeInPhase.elapsedMs < 200 ||
	    fadeCompletePhase.elapsedMs - fadeInPhase.elapsedMs > 1_000 ||
	    titleTransition.elapsedMs > 5_000 ||
	    titleTransition.durationMs > 12_000
	  ) {
    throw new Error(
      `title transition contract failed: ${JSON.stringify(titleTransition)}`
    );
  }
  await waitForPhase(page, "ready", 30_000);
  const landscapeLockedSamples = await page.evaluate(() => {
    window.clearInterval(window.__PROTO_SCROLLER_LOCKED_SOURCE_TIMER__);
    return window.__PROTO_SCROLLER_LOCKED_SOURCE_SAMPLES__ ?? [];
  });
  const landscapeRemainedLockedUntilTitleExit =
    landscapeLockedSamples.length > 0 &&
    landscapeLockedSamples.every(source =>
      source.endsWith("title-loop-landscape.mp4")
    );
  if (!landscapeRemainedLockedUntilTitleExit) {
    throw new Error(
      `landscape source unlocked before title exit: ${JSON.stringify(landscapeLockedSamples)}`
    );
  }
  await page.waitForFunction(
    () => {
      const video = document.getElementById("title-video-backdrop");
      return (
        video instanceof HTMLVideoElement &&
        !document.body.classList.contains("title-backdrop-active") &&
        video.paused
      );
    },
    undefined,
    { timeout: 10_000 }
  );
  await page.keyboard.down("Space");
  try {
    await waitForPhase(page, "charge_started", 30_000);
    await waitForPhase(page, "charge_progress", 30_000);
    await new Promise(resolve => setTimeout(resolve, 250));
  } finally {
    await page.keyboard.up("Space");
  }
  await waitForPhase(page, "charge_released", 30_000);
  const audioContextStates = await page.evaluate(() =>
    (window.__PROTO_SCROLLER_AUDIO_CONTEXTS__ ?? []).map(
      context => context.state
    )
  );
  if (
    audioContextStates.length === 0 ||
    !audioContextStates.includes("running")
  ) {
    throw new Error(
      `Web Audio did not unlock after launch gesture: ${JSON.stringify(audioContextStates)}`
    );
  }
  const workletModules = await page.evaluate(() =>
    (window.__PROTO_SCROLLER_WORKLET_MODULES__ ?? []).map(entry => ({
      ...entry,
    }))
  );
  const expectedWorklets = [
    `${BASE_URL}/game/game.audio.position.worklet.js`,
    `${BASE_URL}/game/game.audio.worklet.js`,
  ];
  const successfulWorklets = workletModules
    .filter(module => module.state === "fulfilled")
    .map(module => module.url)
    .sort();
  if (JSON.stringify(successfulWorklets) !== JSON.stringify(expectedWorklets)) {
    throw new Error(
      `audio worklet modules invalid: ${JSON.stringify(workletModules)}`
    );
  }
  await page.screenshot({ path: SCREENSHOT_PATH });

  await page.keyboard.down("d");
  try {
    await waitForPhase(page, "east_walk_ok", 30_000);
  } finally {
    await page.keyboard.up("d");
  }
  await page.keyboard.down("a");
  try {
    await waitForPhase(page, "pass", 30_000);
  } finally {
    await page.keyboard.up("a");
  }

  await page.evaluate(() => {
    window.__PROTO_SCROLLER_HOLD_TITLE_TRANSITION__ = true;
    window.__PROTO_SCROLLER_TRIGGER_DEFEAT__ = true;
  });
  await waitForPhase(page, "defeat_requested", 30_000);
  await waitForTransition(page, "defeat", "black_ready", 10_000);
  await page.screenshot({ path: DEATH_FADE_SCREENSHOT_PATH });
  await page.evaluate(() => {
    window.__PROTO_SCROLLER_HOLD_TITLE_TRANSITION__ = false;
  });
  await waitForTransition(page, "defeat", "complete", 5_000);
  const deathTransition = await transitionSnapshot(page);
  assertFullBlackTransition(deathTransition, "defeat", 2);
  await page.screenshot({ path: DEATH_SUMMARY_SCREENSHOT_PATH });

  await page.evaluate(() => {
    window.__PROTO_SCROLLER_HOLD_TITLE_TRANSITION__ = true;
  });
  await page.keyboard.press("Tab");
  await page.keyboard.press("Enter");
  await waitForTransition(page, "return_title", "black_ready", 10_000);
  await page.screenshot({ path: RETURN_TITLE_FADE_SCREENSHOT_PATH });
  await page.evaluate(() => {
    window.__PROTO_SCROLLER_HOLD_TITLE_TRANSITION__ = false;
  });
  await waitForTransition(page, "return_title", "complete", 5_000);
  const returnTitleTransition = await transitionSnapshot(page);
  assertFullBlackTransition(returnTitleTransition, "return_title", 3);
  await page.waitForFunction(
    () => document.body.classList.contains("title-backdrop-active"),
    undefined,
    { timeout: 10_000 }
  );

  const phases = await smokeHistory(page);
  assertPhaseContract(phases);

  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto(report.url, {
    waitUntil: "domcontentloaded",
    timeout: 30_000,
  });
  await waitForTitleSource(page, "title-loop-landscape.mp4", 30_000);
  const portraitInitialSource = await titleSourceSnapshot(page);
  await page.setViewportSize({ width: 720, height: 1280 });
  await waitForTitleSource(page, "title-loop-portrait.mp4", 30_000);
  const portraitPreActivationSource = await titleSourceSnapshot(page);
  await page.waitForFunction(
    () => {
      const video = document.getElementById("title-video-backdrop");
      return (
        video instanceof HTMLVideoElement &&
        document.querySelector("canvas.is-ready") &&
        !document.getElementById("runtime-state") &&
        document.body.classList.contains("title-backdrop-active") &&
        video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA &&
        !video.paused &&
        video.currentTime > 0 &&
        video.currentSrc.endsWith("/title-video/title-loop-portrait.mp4")
      );
    },
    undefined,
    { timeout: 120_000 }
  );
  const portraitTitleVideo = await page.evaluate(() => {
    const video = document.getElementById("title-video-backdrop");
    if (!(video instanceof HTMLVideoElement)) return null;
    return {
      currentSrc: video.currentSrc,
      currentTime: video.currentTime,
      duration: video.duration,
      loop: video.loop,
      muted: video.muted,
      paused: video.paused,
      readyState: video.readyState,
      videoHeight: video.videoHeight,
      videoWidth: video.videoWidth,
    };
  });
  await page.waitForTimeout(350);
  const portraitAdvancedTime = await page.evaluate(() => {
    const video = document.getElementById("title-video-backdrop");
    return video instanceof HTMLVideoElement ? video.currentTime : 0;
  });
  if (
    !portraitTitleVideo ||
    portraitTitleVideo.duration < 7.9 ||
    portraitTitleVideo.duration > 8.1 ||
    !portraitTitleVideo.loop ||
    !portraitTitleVideo.muted ||
    portraitTitleVideo.paused ||
    portraitTitleVideo.videoWidth !== 720 ||
    portraitTitleVideo.videoHeight !== 1280 ||
    portraitAdvancedTime <= portraitTitleVideo.currentTime
  ) {
    throw new Error(
      `portrait title video contract failed: ${JSON.stringify({ portraitTitleVideo, portraitAdvancedTime })}`
    );
  }
  await page.keyboard.press("Enter");
  await page.waitForFunction(
    () => window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__?.orientation === "portrait",
    undefined,
    { timeout: 5_000 }
  );
  await page.evaluate(() => {
    window.__PROTO_SCROLLER_LOCKED_SOURCE_SAMPLES__ = [];
    window.__PROTO_SCROLLER_LOCKED_SOURCE_TIMER__ = window.setInterval(() => {
      const video = document.getElementById("title-video-backdrop");
      window.__PROTO_SCROLLER_LOCKED_SOURCE_SAMPLES__.push(video?.currentSrc ?? "");
    }, 25);
  });
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.waitForTimeout(250);
  const portraitPostActivationSource = await titleSourceSnapshot(page);
  if (!portraitPostActivationSource.currentSrc.endsWith("title-loop-portrait.mp4")) {
    throw new Error(
      `portrait source changed after activation: ${JSON.stringify(portraitPostActivationSource)}`
    );
  }
  await page.setViewportSize({ width: 720, height: 1280 });
  await page.waitForFunction(
    () => window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__?.committed === true,
    undefined,
    { timeout: 12_000 }
  );
  const portraitTitleMusicSync = await page.evaluate(() => ({
    ...window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__,
  }));
  if (
    portraitTitleMusicSync.orientation !== "portrait" ||
    !portraitTitleMusicSync.source.endsWith("title-loop-portrait.mp4") ||
    Math.abs(portraitTitleMusicSync.impactSeconds - 66 / 24) > 0.000_001 ||
    portraitTitleMusicSync.trusted !== true ||
    portraitTitleMusicSync.sourceKind !== "AudioBufferSourceNode/non-silent" ||
    Math.abs(portraitTitleMusicSync.renderedSyncError) > 1 / 24
  ) {
    throw new Error(
      `portrait title beat sync failed: ${JSON.stringify(portraitTitleMusicSync)}`
    );
  }
  await page.evaluate(() =>
    new Promise(resolve => {
      const video = document.getElementById("title-video-backdrop");
      if (!(video instanceof HTMLVideoElement)) return resolve();
      const observe = (_now, metadata) => {
        if (metadata.mediaTime >= 66 / 24) resolve();
        else video.requestVideoFrameCallback(observe);
      };
      video.requestVideoFrameCallback(observe);
    })
  );
  await page.screenshot({ path: TITLE_PORTRAIT_SCREENSHOT_PATH });
  await page.waitForFunction(
    () => !document.body.classList.contains("title-backdrop-active"),
    undefined,
    { timeout: 10_000 }
  );
  const portraitLockedSamples = await page.evaluate(() => {
    window.clearInterval(window.__PROTO_SCROLLER_LOCKED_SOURCE_TIMER__);
    return window.__PROTO_SCROLLER_LOCKED_SOURCE_SAMPLES__ ?? [];
  });
  const portraitRemainedLockedUntilTitleExit =
    portraitLockedSamples.length > 0 &&
    portraitLockedSamples.every(source =>
      source.endsWith("title-loop-portrait.mp4")
    );
  if (!portraitRemainedLockedUntilTitleExit) {
    throw new Error(
      `portrait source unlocked before title exit: ${JSON.stringify(portraitLockedSamples)}`
    );
  }

  await page.close();
  page = await context.newPage();
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto(`${BASE_URL}/game/game.html`, {
    waitUntil: "domcontentloaded",
    timeout: 30_000,
  });
  await waitForTitleRuntime(page, 120_000);
  const standaloneShellLayout = await shellLayoutSnapshot(page);
  assertFullscreenShell(standaloneShellLayout, "standalone shell");
  await page.keyboard.press("Enter");
  await page.waitForFunction(
    () => window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__?.committed === true,
    undefined,
    { timeout: 12_000 }
  );
  const standaloneTitleMusicSync = await titleSyncSnapshot(page);
  assertTitleSync(standaloneTitleMusicSync, "landscape", 88 / 24);
  if (standaloneShellLayout.requestVideoFrameCallback !== true) {
    throw new Error("standalone shell lacks requestVideoFrameCallback");
  }
  await assertNoNewRuntimeErrors("standalone shell");
  standaloneShellLayout.runtimeErrors = [];
  standaloneShellLayout.requestErrors = [];
  await page.close();

  page = await context.newPage();
  await page.setViewportSize({ width: 1280, height: 720 });
  const fallbackUrl = `${BASE_URL}/game/game.html?forceTitleVideoReject=1&webSmoke=1`;
  await page.goto(fallbackUrl, {
    waitUntil: "domcontentloaded",
    timeout: 30_000,
  });
  await waitForTitleRuntime(page, 120_000);
  const fallbackStartedAt = Date.now();
  await page.keyboard.press("Enter");
  await page.waitForFunction(
    () => window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__?.committed === true,
    undefined,
    { timeout: 12_000 }
  );
  await page.waitForFunction(
    () =>
      (window.__PROTO_SCROLLER_AUDIO_BUFFER_STARTS__ ?? []).some(
        entry => entry.hasBuffer && entry.length > 0
      ),
    undefined,
    { timeout: 10_000 }
  );
  await page.waitForFunction(
    () => !document.body.classList.contains("title-backdrop-active"),
    undefined,
    { timeout: 10_000 }
  );
  await waitForPhase(page, "ready", 30_000);
  const fallbackReadyPhase = (await smokeHistory(page)).find(
    entry => entry.status === "ready"
  );
  const titleMusicFallback = {
    ...(await titleSyncSnapshot(page)),
    boundedCompletionMs: Date.now() - fallbackStartedAt,
    persistentBackgroundMusic:
      fallbackReadyPhase?.details?.background_music_playing === true,
    transitionCompleted: true,
    gameplayNotStranded: true,
  };
  if (
    titleMusicFallback.fallback !== true ||
    titleMusicFallback.fallbackReason !== "video-playback-rejected" ||
    titleMusicFallback.boundedCompletionMs > 12_000 ||
    titleMusicFallback.persistentBackgroundMusic !== true
  ) {
    throw new Error(
      `title music fallback failed: ${JSON.stringify(titleMusicFallback)}`
    );
  }
  await assertNoNewRuntimeErrors("fallback shell");
  await page.close();
  page = null;
  if (browserErrors.length > 0) {
    throw new Error(`browser console errors: ${browserErrors.join(" | ")}`);
  }
  if (requestFailures.length > 0) {
    throw new Error(`runtime request failures: ${requestFailures.join(" | ")}`);
  }
  report = {
    ...report,
    status: "PASS",
    phases,
    audioContextStates,
    workletModules,
    landscapeTitleMusicSync,
    titleSourceSwitching: {
      landscape: {
        initialSource: landscapeInitialSource.currentSrc,
        preActivationSource: landscapePreActivationSource.currentSrc,
        preActivationSwitched:
          landscapeInitialSource.currentSrc !==
          landscapePreActivationSource.currentSrc,
        postActivationSource: landscapePostActivationSource.currentSrc,
        remainedLockedUntilTitleExit: landscapeRemainedLockedUntilTitleExit,
      },
      portrait: {
        initialSource: portraitInitialSource.currentSrc,
        preActivationSource: portraitPreActivationSource.currentSrc,
        preActivationSwitched:
          portraitInitialSource.currentSrc !== portraitPreActivationSource.currentSrc,
        postActivationSource: portraitPostActivationSource.currentSrc,
        remainedLockedUntilTitleExit: portraitRemainedLockedUntilTitleExit,
      },
    },
    titleVideo: {
      ...titleVideoStart,
      advancedTime: titleVideoAdvancedTime,
      screenshot: path.relative(ROOT, TITLE_LANDSCAPE_SCREENSHOT_PATH),
      stoppedForGameplay: true,
    },
    titleTransition,
    deathTransition: {
      ...deathTransition,
      screenshot: path.relative(ROOT, DEATH_FADE_SCREENSHOT_PATH),
      summaryScreenshot: path.relative(ROOT, DEATH_SUMMARY_SCREENSHOT_PATH),
    },
    returnTitleTransition: {
      ...returnTitleTransition,
      screenshot: path.relative(ROOT, RETURN_TITLE_FADE_SCREENSHOT_PATH),
    },
    portraitTitleVideo: {
      ...portraitTitleVideo,
      advancedTime: portraitAdvancedTime,
      screenshot: path.relative(ROOT, TITLE_PORTRAIT_SCREENSHOT_PATH),
    },
    portraitTitleMusicSync,
    standaloneTitleMusicSync,
    standaloneShellLayout,
    titleMusicFallback,
    screenshot: path.relative(ROOT, SCREENSHOT_PATH),
  };
  console.log(`[WEB-GAMEPLAY-SMOKE-PASS] phases=${EXPECTED_PHASES.join(",")}`);
} catch (error) {
  if (page) {
    await page.screenshot({ path: FAILURE_SCREENSHOT_PATH }).catch(() => {});
    report.failureScreenshot = path.relative(ROOT, FAILURE_SCREENSHOT_PATH);
    report.phases = await smokeHistory(page).catch(() => []);
  }
  report.error =
    error instanceof Error ? (error.stack ?? error.message) : String(error);
  report.serverOutput = serverOutput.slice(-60);
  console.error(`[WEB-GAMEPLAY-SMOKE-FAIL] ${report.error}`);
  process.exitCode = 1;
} finally {
  await writeFile(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  await rm(SMOKE_ENGINE_DIR, { recursive: true, force: true });
  if (browser) await browser.close();
  if (server?.pid && server.exitCode === null) {
    try {
      process.kill(-server.pid, "SIGTERM");
    } catch {}
    await Promise.race([
      new Promise(resolve => server.once("exit", resolve)),
      new Promise(resolve => setTimeout(resolve, 2_000)),
    ]);
    if (server.exitCode === null) {
      try {
        process.kill(-server.pid, "SIGKILL");
      } catch {}
    }
  }
}

async function waitForHttp(url, timeoutMs, child) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) {
      throw new Error(
        `Vite exited before readiness with code ${child.exitCode}`
      );
    }
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {}
    await new Promise(resolve => setTimeout(resolve, 150));
  }
  throw new Error(`Timed out waiting for ${url}`);
}

function attachPageHandlers(activePage) {
  if (instrumentedPages.has(activePage)) return;
  instrumentedPages.add(activePage);
  activePage.on("pageerror", error =>
    browserErrors.push(`pageerror: ${error.message}`)
  );
  activePage.on("console", message => {
    if (
      message.type() === "error" &&
      !message.text().startsWith("Failed to load resource:")
    ) {
      browserErrors.push(`console: ${message.text()}`);
    }
  });
  activePage.on("response", response => {
    if (response.status() >= 400) {
      httpErrors.push(`${response.status()} ${response.url()}`);
    }
  });
  activePage.on("requestfailed", request => {
    const url = request.url();
    if (
      url.includes("/game/") ||
      url.includes("/manus-storage/") ||
      url.includes("/remote-engine/") ||
      url.includes("/title-video/")
    ) {
      requestFailures.push(
        `${url}: ${request.failure()?.errorText ?? "unknown failure"}`
      );
    }
  });
}

async function waitForTitleSource(activePage, suffix, timeoutMs) {
  await activePage.waitForFunction(
    expected => {
      const video = document.getElementById("title-video-backdrop");
      return (
        video instanceof HTMLVideoElement &&
        video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA &&
        video.currentSrc.endsWith(expected)
      );
    },
    suffix,
    { timeout: timeoutMs }
  );
}

async function titleSourceSnapshot(activePage) {
  return activePage.evaluate(() => {
    const video = document.getElementById("title-video-backdrop");
    return {
      currentSrc: video instanceof HTMLVideoElement ? video.currentSrc : "",
      orientation: matchMedia("(orientation: portrait)").matches
        ? "portrait"
        : "landscape",
    };
  });
}

async function waitForTitleRuntime(activePage, timeoutMs) {
  await activePage.waitForFunction(
    () => {
      const canvas = document.getElementById("canvas");
      const video = document.getElementById("title-video-backdrop");
      return (
        canvas instanceof HTMLCanvasElement &&
        video instanceof HTMLVideoElement &&
        !document.getElementById("status") &&
        document.body.classList.contains("title-backdrop-active") &&
        video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA &&
        video.currentTime > 0
      );
    },
    undefined,
    { timeout: timeoutMs }
  );
}

async function titleSyncSnapshot(activePage) {
  return activePage.evaluate(() => ({
    ...window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__,
  }));
}

function assertTitleSync(sync, orientation, impactSeconds) {
  if (
    sync.orientation !== orientation ||
    sync.sourceKind !== "AudioBufferSourceNode/non-silent" ||
    sync.trusted !== true ||
    Math.abs(sync.impactSeconds - impactSeconds) > 0.000_001 ||
    Math.abs(sync.renderedSyncError) > 1 / 24 ||
    sync.committed !== true
  ) {
    throw new Error(`title beat sync failed: ${JSON.stringify(sync)}`);
  }
}

async function shellLayoutSnapshot(activePage) {
  return activePage.evaluate(() => {
    const canvas = document.getElementById("canvas");
    const video = document.getElementById("title-video-backdrop");
    const bodyStyle = getComputedStyle(document.body);
    const canvasRect = canvas?.getBoundingClientRect();
    return {
      bodyMargin: bodyStyle.margin,
      bodyWidth: document.body.getBoundingClientRect().width,
      bodyHeight: document.body.getBoundingClientRect().height,
      canvasLeft: canvasRect?.left ?? -1,
      canvasTop: canvasRect?.top ?? -1,
      canvasWidth: canvasRect?.width ?? 0,
      canvasHeight: canvasRect?.height ?? 0,
      viewportWidth: innerWidth,
      viewportHeight: innerHeight,
      titleBackdropActive: document.body.classList.contains(
        "title-backdrop-active"
      ),
      requestVideoFrameCallback:
        video instanceof HTMLVideoElement &&
        typeof video.requestVideoFrameCallback === "function",
    };
  });
}

function assertFullscreenShell(layout, label) {
  if (
    layout.bodyMargin !== "0px" ||
    layout.canvasLeft !== 0 ||
    layout.canvasTop !== 0 ||
    Math.abs(layout.canvasWidth - layout.viewportWidth) > 1 ||
    Math.abs(layout.canvasHeight - layout.viewportHeight) > 1 ||
    layout.titleBackdropActive !== true
  ) {
    throw new Error(`${label} layout failed: ${JSON.stringify(layout)}`);
  }
}

async function assertNoNewRuntimeErrors(label) {
  if (browserErrors.length > 0 || requestFailures.length > 0 || httpErrors.length > 0) {
    throw new Error(
      `${label} runtime errors: ${JSON.stringify({ browserErrors, requestFailures, httpErrors })}`
    );
  }
}

async function waitForTransition(activePage, kind, phase, timeoutMs) {
  await activePage.waitForFunction(
    expected => {
      const transition = window.__PROTO_SCROLLER_TITLE_TRANSITION__;
      return (
        transition?.kind === expected.kind &&
        transition?.phase === expected.phase
      );
    },
    { kind, phase },
    { timeout: timeoutMs }
  );
}

async function transitionSnapshot(activePage) {
  return activePage.evaluate(() => ({
    ...window.__PROTO_SCROLLER_TITLE_TRANSITION__,
    phases: window.__PROTO_SCROLLER_TITLE_TRANSITION__?.phases?.map(entry => ({
      ...entry,
    })),
  }));
}

function assertFullBlackTransition(transition, kind, boomCount) {
  const phases = transition.phases ?? [];
  const names = phases.map(entry => entry.phase);
  const expected = ["fade_out", "black", "black_ready", "fade_in", "complete"];
  const fadeOut = phases.find(entry => entry.phase === "fade_out");
  const black = phases.find(entry => entry.phase === "black");
  if (
    transition.kind !== kind ||
    JSON.stringify(names) !== JSON.stringify(expected) ||
    fadeOut?.boomCount !== boomCount - 1 ||
    black?.boomCount !== boomCount ||
    black?.overlayAlpha < 0.999 ||
    transition.boomCount !== boomCount ||
    transition.phase !== "complete" ||
    transition.overlayAlpha > 0.001
  ) {
    throw new Error(
      `${kind} full-black transition failed: ${JSON.stringify(transition)}`
    );
  }
}

async function smokeHistory(activePage) {
  return activePage.evaluate(
    () => window.__PROTO_SCROLLER_SMOKE_HISTORY__ ?? []
  );
}

async function waitForPhase(activePage, phase, timeoutMs) {
  await activePage.waitForFunction(
    expected => {
      const history = window.__PROTO_SCROLLER_SMOKE_HISTORY__ ?? [];
      const failure = history.find(entry => entry.status === "fail");
      if (failure)
        throw new Error(failure.details?.message ?? "Godot smoke probe failed");
      return history.some(entry => entry.status === expected);
    },
    phase,
    { timeout: timeoutMs }
  );
}

function assertPhaseContract(phases) {
  const statuses = phases.map(entry => entry.status);
  if (JSON.stringify(statuses) !== JSON.stringify(EXPECTED_PHASES)) {
    throw new Error(`unexpected smoke phases: ${JSON.stringify(statuses)}`);
  }
  phases.forEach((entry, index) => {
    if (entry.phase_index !== index + 1) {
      throw new Error(
        `non-monotonic phase index at ${entry.status}: ${entry.phase_index}`
      );
    }
  });
  const chargeStarted = phases[1];
  const chargeProgress = phases[2];
  const chargeReleased = phases[3];
  const east = phases[4];
  const west = phases[5];
  if (
    chargeStarted.details.frame !== 0 ||
    chargeStarted.details.particles !== false ||
    !String(chargeStarted.details.animation).startsWith("attack_")
  ) {
    throw new Error(
      `charge did not freeze first frame before particles armed: ${JSON.stringify(chargeStarted.details)}`
    );
  }
  if (
    chargeProgress.details.duration < 0.6 ||
    chargeProgress.details.progress < 0.35 ||
    chargeProgress.details.multiplier <= 1.0 ||
    chargeProgress.details.multiplier > 2.0 ||
    chargeProgress.details.frame !== 0 ||
    chargeProgress.details.particles !== true
  ) {
    throw new Error(
      `charge progress contract failed: ${JSON.stringify(chargeProgress.details)}`
    );
  }
  if (
    chargeReleased.details.damage <= 360 ||
    chargeReleased.details.damage > 720 ||
    chargeReleased.details.playing !== true
  ) {
    throw new Error(
      `charge release contract failed: ${JSON.stringify(chargeReleased.details)}`
    );
  }
  if (phases[0].details.background_music_playing !== true) {
    throw new Error(
      `background music did not start after launch gesture: ${JSON.stringify(phases[0].details)}`
    );
  }
  if (
    east.details.animation !== "walk_e" ||
    east.details.frame_before === east.details.frame_after ||
    east.details.servo_count < 1 ||
    east.details.footstep_count < 1
  ) {
    throw new Error(
      `east animation continuity failed: ${JSON.stringify(east.details)}`
    );
  }
  if (
    west.details.animation !== "walk_w" ||
    west.details.frame_before === west.details.frame_after
  ) {
    throw new Error(
      `west animation continuity failed: ${JSON.stringify(west.details)}`
    );
  }
}
