import "./index.css";
import { createGodotFileSizes } from "./lib/godotLoaderState";
import {
  calculateWebRenderResolution,
  selectWebRenderTier,
  type WebRenderResolution,
} from "./lib/webRenderResolution";

type GodotConfig = {
  args: string[];
  audioWorkletBase?: string;
  canvas: HTMLCanvasElement;
  canvasResizePolicy: number;
  emscriptenPoolSize: number;
  ensureCrossOriginIsolationHeaders: boolean;
  executable: string;
  experimentalVK: boolean;
  fileSizes: Record<string, number>;
  focusCanvas: boolean;
  gdextensionLibs: string[];
  godotPoolSize: number;
  mainPack: string;
};

type GodotEngine = {
  startGame: (options: {
    onProgress: (current: number, total: number) => void;
  }) => Promise<void>;
};

type GodotEngineConstructor = {
  new (config: GodotConfig): GodotEngine;
  getMissingFeatures: (options: { threads: boolean }) => string[];
};

declare global {
  interface Window {
    Engine?: GodotEngineConstructor;
    __PROTO_SCROLLER_TITLE_MUSIC_SYNC__?: TitleMusicSyncTelemetry;
    protoScrollerCancelTitleBeatCommit?: (reason?: string) => void;
    protoScrollerMarkTitleMusicPrewarm?: (status: string) => void;
    protoScrollerScheduleTitleBeatCommit?: (
      commitCallback: (...args: unknown[]) => void,
      calibrationCallback?: (...args: unknown[]) => void
    ) => boolean;
    protoScrollerSetTitleBackdropActive?: (active: boolean) => void;
    protoScrollerResolution?: WebRenderResolution;
  }
}

type TitleOrientation = "landscape" | "portrait";
interface TitleMusicSyncTelemetry {
  orientation: TitleOrientation;
  source: string;
  sourceKind: string;
  impactSeconds: number;
  videoTime: number | null;
  outputLatency: number;
  actualOutputSchedule: number | null;
  renderedVideoTime: number | null;
  renderedSyncError: number | null;
  trusted: boolean;
  audioContextState: string;
  fallback: boolean;
  fallbackReason: string | null;
  cancelled: boolean;
  cancelReason: string | null;
  committed: boolean;
  commitStatus: string;
  prewarmStatus: string;
}

const ENGINE_SCRIPT_ID = "proto-scroller-godot-engine";
const GAME_PACK_VERSION = "5a37cd64-voice-priority";
const REMOTE_ENGINE_PATH = "/manus-storage/game_e2f01e77";
const REMOTE_PACK_PATH = `/manus-storage/game_ffe4d3c1.pck?v=${GAME_PACK_VERSION}`;
const ENGINE_WASM_BYTES = 39_513_091;
const GAME_PACK_BYTES = 7_763_444;
const searchParameters = new URLSearchParams(window.location.search);
const root = document.getElementById("root");

if (!root) {
  throw new Error("Missing game root element.");
}

root.innerHTML = `
  <main class="game-host">
    <picture id="title-poster-backdrop" class="title-poster-backdrop" aria-hidden="true">
      <source media="(orientation: portrait)" srcset="/title-video/title-poster-portrait.jpg" />
      <img src="/title-video/title-poster-landscape.jpg" alt="" />
    </picture>
    <video
      id="title-video-backdrop"
      class="title-video-backdrop"
      muted
      loop
      autoplay
      playsinline
      preload="auto"
      aria-hidden="true"
    >
      <source media="(orientation: portrait)" src="/title-video/title-loop-portrait.mp4" type="video/mp4" />
      <source src="/title-video/title-loop-landscape.mp4" type="video/mp4" />
    </video>
    <canvas id="canvas" class="game-canvas" tabindex="0" aria-label="Game template - scroller">
      Your browser does not support the canvas element.
    </canvas>
    <section id="runtime-state" class="runtime-state" role="status" aria-live="polite">
      <img class="runtime-splash" src="/game/game.png" alt="" />
      <progress id="runtime-progress" class="runtime-progress"></progress>
      <div id="runtime-notice" class="runtime-notice"></div>
    </section>
  </main>
`;

function requireElement<T extends HTMLElement>(id: string): T {
  const element = document.getElementById(id);
  if (!element) throw new Error(`Missing loader element: ${id}`);
  return element as T;
}

const canvas = requireElement<HTMLCanvasElement>("canvas");
const titleVideoBackdrop = requireElement<HTMLVideoElement>(
  "title-video-backdrop"
);
const TITLE_VIDEO_LANDSCAPE = "/title-video/title-loop-landscape.mp4";
const TITLE_VIDEO_PORTRAIT = "/title-video/title-loop-portrait.mp4";
const TITLE_IMPACT_SECONDS: Readonly<Record<TitleOrientation, number>> = {
  landscape: 88 / 24,
  portrait: 66 / 24,
};
const TITLE_VIDEO_SECONDS = 8;
const TITLE_AUDIO_MAX_OUTPUT_LATENCY_SECONDS = 0.2;
const TITLE_PREWARM_TIMEOUT_MS = 1_250;
const TITLE_SCHEDULER_TIMEOUT_MS = 9_500;
const TITLE_SOURCE_CAPTURE_TIMEOUT_MS = 1_500;
const TITLE_AUDIO_SCHEDULE_AHEAD_SECONDS = 1.0;
const forceTitleVideoReject =
  new URLSearchParams(window.location.search).get("forceTitleVideoReject") ===
  "1";
type TrackedAudioContext = AudioContext;
const trackedAudioContexts = new Set<TrackedAudioContext>();
let titleSourceLocked = false;
let lockedTitleOrientation: TitleOrientation | null = null;
let titleScheduleGeneration = 0;
let titleScheduleFrame = 0;
let titleScheduleTimer = 0;
let titleTargetOutputPerformanceTime = 0;
let pendingSourceCapture:
  | {
      generation: number;
	      impactSeconds: number;
	      scheduleToImpact: boolean;
	      targetOutputPerformanceTime: number;
	      scheduled: (secondsUntilRendered: number) => void;
      complete: () => void;
    }
  | undefined;

function selectedTitleOrientation(): TitleOrientation {
  if (titleSourceLocked && lockedTitleOrientation)
    return lockedTitleOrientation;
  return window.matchMedia("(orientation: portrait)").matches
    ? "portrait"
    : "landscape";
}
function titleSourceFor(orientation: TitleOrientation): string {
  return orientation === "portrait"
    ? TITLE_VIDEO_PORTRAIT
    : TITLE_VIDEO_LANDSCAPE;
}
function selectTitleVideoSource(force = false): void {
  if (titleSourceLocked && !force) return;
  const source = titleSourceFor(selectedTitleOrientation());
  const currentPath = new URL(
    titleVideoBackdrop.currentSrc || titleVideoBackdrop.src || source,
    location.href
  ).pathname;
  if (currentPath === source && !force) return;
  const shouldPlay =
    !titleVideoBackdrop.paused ||
    document.body.classList.contains("title-backdrop-active");
  titleVideoBackdrop.src = source;
  titleVideoBackdrop.load();
  if (shouldPlay) void titleVideoBackdrop.play().catch(() => undefined);
}
function boundedOutputLatency(context: TrackedAudioContext): number {
  return Math.min(
    Math.max(context.outputLatency || context.baseLatency || 0, 0),
    TITLE_AUDIO_MAX_OUTPUT_LATENCY_SECONDS
  );
}
function outputPerformanceTime(
  context: TrackedAudioContext,
  scheduledContextTime: number
): number {
  const timestamp = context.getOutputTimestamp?.();
  if (
    timestamp &&
    timestamp.contextTime !== undefined &&
    timestamp.performanceTime !== undefined &&
    Number.isFinite(timestamp.contextTime) &&
    Number.isFinite(timestamp.performanceTime)
  ) {
    return (
      timestamp.performanceTime +
      (scheduledContextTime - timestamp.contextTime) * 1_000
    );
  }
  return (
    performance.now() +
    Math.max(
      0,
      scheduledContextTime - context.currentTime + boundedOutputLatency(context)
    ) *
      1_000
  );
}
function bufferContainsSignal(buffer: AudioBuffer | null): boolean {
  if (!buffer || buffer.length === 0) return false;
  for (let channel = 0; channel < buffer.numberOfChannels; channel += 1) {
    const samples = buffer.getChannelData(channel);
    const stride = Math.max(1, Math.floor(samples.length / 4_096));
    for (let sample = 0; sample < samples.length; sample += stride) {
      if (Math.abs(samples[sample] ?? 0) > 0.000001) return true;
    }
  }
  return false;
}
function installAudioContextTracking(): void {
  const scope = window as Window &
    typeof globalThis & {
      webkitAudioContext?: typeof AudioContext;
    };
  const NativeAudioContext = scope.AudioContext ?? scope.webkitAudioContext;
  if (!NativeAudioContext) return;
  const marker = NativeAudioContext as typeof AudioContext & {
    __protoScrollerWrapped?: boolean;
  };
  if (marker.__protoScrollerWrapped) return;
  const WrappedAudioContext = class extends NativeAudioContext {
    constructor(options?: AudioContextOptions) {
      super(options);
      trackedAudioContexts.add(this);
    }
  };
  (
    WrappedAudioContext as typeof AudioContext & {
      __protoScrollerWrapped: boolean;
    }
  ).__protoScrollerWrapped = true;
  scope.AudioContext = WrappedAudioContext;
  if (scope.webkitAudioContext) scope.webkitAudioContext = WrappedAudioContext;
}
function installAudioBufferSourceStartProbe(): void {
  const prototype = window.AudioBufferSourceNode?.prototype as
    | (AudioBufferSourceNode & { __protoScrollerStartWrapped?: boolean })
    | undefined;
  if (!prototype || prototype.__protoScrollerStartWrapped) return;
  const nativeStart = prototype.start;
  prototype.start = function start(
    when = 0,
    offset = 0,
    duration?: number
  ): void {
    let effectiveWhen = when;
    const capture = pendingSourceCapture;
    const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__;
    if (
      capture &&
      telemetry &&
      capture.generation === titleScheduleGeneration &&
      telemetry.commitStatus === "callback-invoked" &&
      bufferContainsSignal(this.buffer)
    ) {
      const context = this.context as TrackedAudioContext;
      const immediateSchedule = when > 0 ? when : context.currentTime;
	      const immediateOutputPerformanceTime = outputPerformanceTime(
	        context,
	        immediateSchedule
	      );
	      const schedule = capture.scheduleToImpact
	        ? context.currentTime +
	          Math.max(
	            0,
	            (capture.targetOutputPerformanceTime -
	              immediateOutputPerformanceTime) /
	              1_000
	          )
	        : immediateSchedule;
      effectiveWhen = schedule;
      const secondsUntilRendered = Math.max(
        0,
        (outputPerformanceTime(context, schedule) - performance.now()) / 1_000
      );
      const renderedVideoTime =
        (titleVideoBackdrop.currentTime + secondsUntilRendered) %
        TITLE_VIDEO_SECONDS;
      telemetry.sourceKind = "AudioBufferSourceNode/non-silent";
      telemetry.actualOutputSchedule = schedule;
      telemetry.renderedVideoTime = renderedVideoTime;
      telemetry.renderedSyncError = renderedVideoTime - capture.impactSeconds;
      telemetry.videoTime = titleVideoBackdrop.currentTime;
      telemetry.committed = true;
      telemetry.commitStatus = "captured";
      pendingSourceCapture = undefined;
      capture.scheduled(secondsUntilRendered);
      capture.complete();
    }
    if (duration === undefined) nativeStart.call(this, effectiveWhen, offset);
    else nativeStart.call(this, effectiveWhen, offset, duration);
  };
  prototype.__protoScrollerStartWrapped = true;
}
installAudioContextTracking();
installAudioBufferSourceStartProbe();
function createTitleTelemetry(
  orientation: TitleOrientation,
  trusted: boolean
): TitleMusicSyncTelemetry {
  return {
    orientation,
    source: titleSourceFor(orientation),
    sourceKind: "pending",
    impactSeconds: TITLE_IMPACT_SECONDS[orientation],
    videoTime: null,
    outputLatency: 0,
    actualOutputSchedule: null,
    renderedVideoTime: null,
    renderedSyncError: null,
    trusted,
    audioContextState: "unavailable",
    fallback: false,
    fallbackReason: null,
    cancelled: false,
    cancelReason: null,
    committed: false,
    commitStatus: "scheduled",
    prewarmStatus: "waiting",
  };
}
function finishTitleCommit(
  generation: number,
  calibrationCallback?: (...args: unknown[]) => void
): void {
  if (generation === titleScheduleGeneration) calibrationCallback?.("complete");
}
function commitTitleMusic(
  generation: number,
  commitCallback: (...args: unknown[]) => void,
  calibrationCallback?: (...args: unknown[]) => void,
  fallbackReason?: string
): void {
  if (generation !== titleScheduleGeneration) return;
  if (titleScheduleFrame) cancelAnimationFrame(titleScheduleFrame);
  if (titleScheduleTimer) window.clearTimeout(titleScheduleTimer);
  titleScheduleFrame = 0;
  titleScheduleTimer = 0;
  const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__;
  if (
    !telemetry ||
    telemetry.committed ||
    telemetry.commitStatus === "callback-invoked"
  )
    return;
  if (fallbackReason) {
    telemetry.fallback = true;
    telemetry.fallbackReason = fallbackReason;
  }
  telemetry.videoTime = titleVideoBackdrop.currentTime;
  telemetry.commitStatus = "callback-invoked";
  pendingSourceCapture = {
	    generation,
	    impactSeconds: telemetry.impactSeconds,
	    scheduleToImpact: !fallbackReason,
	    targetOutputPerformanceTime: titleTargetOutputPerformanceTime,
	    scheduled: secondsUntilRendered =>
      calibrationCallback?.("scheduled", secondsUntilRendered),
    complete: () => finishTitleCommit(generation, calibrationCallback),
  };
  commitCallback();
  window.setTimeout(() => {
    if (generation !== titleScheduleGeneration || telemetry.committed) return;
    telemetry.fallback = true;
    telemetry.fallbackReason ??= "non-silent-source-capture-timeout";
    telemetry.sourceKind = "commit-callback-fallback";
    telemetry.committed = true;
    telemetry.commitStatus = "fallback-complete";
    pendingSourceCapture = undefined;
    finishTitleCommit(generation, calibrationCallback);
  }, TITLE_SOURCE_CAPTURE_TIMEOUT_MS);
}
async function runTitleBeatScheduler(
  generation: number,
  commitCallback: (...args: unknown[]) => void,
  calibrationCallback?: (...args: unknown[]) => void
): Promise<void> {
  const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__;
  if (!telemetry) return;
  const contexts = Array.from(trackedAudioContexts);
  try {
    await Promise.all(contexts.map(context => context.resume()));
  } catch {
    commitTitleMusic(
      generation,
      commitCallback,
      calibrationCallback,
      "audio-context-resume-rejected"
    );
    return;
  }
  if (generation !== titleScheduleGeneration) return;
  const context = contexts.find(candidate => candidate.state === "running");
  telemetry.audioContextState = context?.state ?? "unavailable";
  telemetry.outputLatency = context ? boundedOutputLatency(context) : 0;
  if (!context || !telemetry.trusted) {
    commitTitleMusic(
      generation,
      commitCallback,
      calibrationCallback,
      "trusted-running-audio-context-unavailable"
    );
    return;
  }
  calibrationCallback?.("prewarm");
  const prewarmDeadline = performance.now() + TITLE_PREWARM_TIMEOUT_MS;
  while (
    telemetry.prewarmStatus !== "restored" &&
    performance.now() < prewarmDeadline
  ) {
    await new Promise<void>(resolve => requestAnimationFrame(() => resolve()));
    if (generation !== titleScheduleGeneration) return;
  }
  if (telemetry.prewarmStatus !== "restored")
    telemetry.prewarmStatus = "timed-out";
  try {
    if (forceTitleVideoReject) throw new Error("forced title video rejection");
    await titleVideoBackdrop.play();
  } catch {
    commitTitleMusic(
      generation,
      commitCallback,
      calibrationCallback,
      "video-playback-rejected"
    );
    return;
  }
	  const currentVideoTime =
	    ((titleVideoBackdrop.currentTime % TITLE_VIDEO_SECONDS) +
	      TITLE_VIDEO_SECONDS) %
	    TITLE_VIDEO_SECONDS;
	  let secondsUntilImpact = telemetry.impactSeconds - currentVideoTime;
	  if (secondsUntilImpact <= TITLE_AUDIO_SCHEDULE_AHEAD_SECONDS)
	    secondsUntilImpact += TITLE_VIDEO_SECONDS;
	  titleTargetOutputPerformanceTime =
	    performance.now() + secondsUntilImpact * 1_000;
	  const secondsUntilCommit =
	    secondsUntilImpact - TITLE_AUDIO_SCHEDULE_AHEAD_SECONDS;
	  const targetPerformanceTime =
	    titleTargetOutputPerformanceTime -
	    TITLE_AUDIO_SCHEDULE_AHEAD_SECONDS * 1_000;
  titleScheduleTimer = window.setTimeout(
    () => commitTitleMusic(generation, commitCallback, calibrationCallback),
    secondsUntilCommit * 1_000
  );
  const deadline = performance.now() + TITLE_SCHEDULER_TIMEOUT_MS;
  const sample = (): void => {
    if (generation !== titleScheduleGeneration) return;
    telemetry.videoTime = titleVideoBackdrop.currentTime;
    if (
	      performance.now() >= targetPerformanceTime
    ) {
      commitTitleMusic(generation, commitCallback, calibrationCallback);
      return;
    }
    if (performance.now() >= deadline || titleVideoBackdrop.error) {
      commitTitleMusic(
        generation,
        commitCallback,
        calibrationCallback,
        "video-scheduler-timeout"
      );
      return;
    }
    titleScheduleFrame = requestAnimationFrame(sample);
  };
  titleScheduleFrame = requestAnimationFrame(sample);
}
window.protoScrollerMarkTitleMusicPrewarm = status => {
  const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__;
  if (telemetry) telemetry.prewarmStatus = status;
};
window.protoScrollerCancelTitleBeatCommit = (reason = "host-cancelled") => {
  titleScheduleGeneration += 1;
  if (titleScheduleFrame) cancelAnimationFrame(titleScheduleFrame);
  if (titleScheduleTimer) window.clearTimeout(titleScheduleTimer);
	  titleScheduleFrame = 0;
	  titleScheduleTimer = 0;
	  titleTargetOutputPerformanceTime = 0;
  pendingSourceCapture = undefined;
  const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__;
  if (telemetry && !telemetry.committed) {
    telemetry.cancelled = true;
    telemetry.cancelReason = reason;
    telemetry.commitStatus = "cancelled";
  }
  titleSourceLocked = false;
  lockedTitleOrientation = null;
};
window.protoScrollerScheduleTitleBeatCommit = (
  commitCallback,
  calibrationCallback
) => {
  window.protoScrollerCancelTitleBeatCommit?.("rescheduled");
  const generation = titleScheduleGeneration;
  lockedTitleOrientation = selectedTitleOrientation();
  titleSourceLocked = true;
  selectTitleVideoSource(true);
  window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__ = createTitleTelemetry(
    lockedTitleOrientation,
    navigator.userActivation?.isActive === true
  );
  void runTitleBeatScheduler(generation, commitCallback, calibrationCallback);
  return true;
};
window.addEventListener("resize", () => selectTitleVideoSource(), {
  passive: true,
});
selectTitleVideoSource();
const runtimeState = requireElement<HTMLElement>("runtime-state");
const runtimeProgress = requireElement<HTMLProgressElement>("runtime-progress");
const runtimeNotice = requireElement<HTMLElement>("runtime-notice");
const renderTier = selectWebRenderTier(
  searchParameters.get("renderTier"),
  navigator.maxTouchPoints
);
let resizeFrame = 0;

window.protoScrollerSetTitleBackdropActive = (active: boolean): void => {
  document.body.classList.toggle("title-backdrop-active", active);
  if (active) {
    const playPromise = titleVideoBackdrop.play();
    if (playPromise) void playPromise.catch(() => undefined);
  } else {
    titleVideoBackdrop.pause();
  }
};
titleVideoBackdrop.addEventListener(
  "playing",
  () => titleVideoBackdrop.classList.add("is-ready"),
  { once: true }
);
// Smoke capture may observe the decoded impact frame; synchronization remains rAF-driven.
titleVideoBackdrop.requestVideoFrameCallback?.(() => undefined);
window.protoScrollerSetTitleBackdropActive(true);

function updateCanvasResolution(): void {
  const bounds = canvas.getBoundingClientRect();
  const resolution = calculateWebRenderResolution(
    bounds.width || window.innerWidth,
    bounds.height || window.innerHeight,
    window.devicePixelRatio,
    renderTier
  );

  if (canvas.width !== resolution.width) canvas.width = resolution.width;
  if (canvas.height !== resolution.height) canvas.height = resolution.height;
  canvas.dataset.renderTier = resolution.tier;
  canvas.dataset.renderResolution = `${resolution.width}x${resolution.height}`;
  window.protoScrollerResolution = resolution;
}

function queueCanvasResolutionUpdate(): void {
  window.cancelAnimationFrame(resizeFrame);
  resizeFrame = window.requestAnimationFrame(updateCanvasResolution);
}

function showDownloadProgress(current: number, total: number): void {
  if (current > 0 && total > 0) {
    runtimeProgress.value = current;
    runtimeProgress.max = total;
  } else {
    runtimeProgress.removeAttribute("value");
    runtimeProgress.removeAttribute("max");
  }
}

function showError(message: string): void {
  console.error(message);
  runtimeProgress.hidden = true;
  runtimeNotice.textContent = message;
  runtimeNotice.hidden = false;
}

function nextPaint(): Promise<void> {
  return new Promise(resolve => window.requestAnimationFrame(() => resolve()));
}

updateCanvasResolution();
window.addEventListener("resize", queueCanvasResolutionUpdate, {
  passive: true,
});

async function startEngine(): Promise<void> {
  const Engine = window.Engine;
  if (!Engine) return;

  const missing = Engine.getMissingFeatures({ threads: false });
  if (missing.length > 0) {
    showError(`Missing browser features: ${missing.join(", ")}`);
    return;
  }

  const useLocalGameFiles =
    import.meta.env.DEV && searchParameters.has("localGame");
  const useSplitWorkletSmoke =
    useLocalGameFiles && searchParameters.has("splitWorklets");
  const executable = useSplitWorkletSmoke
    ? "/remote-engine/smoke-engine"
    : useLocalGameFiles
      ? "/game/game"
      : REMOTE_ENGINE_PATH;
  const mainPack = useLocalGameFiles ? "/game/game.pck" : REMOTE_PACK_PATH;
  const engine = new Engine({
    args: [],
    audioWorkletBase: "/game/game",
    canvas,
    canvasResizePolicy: 0,
    emscriptenPoolSize: 8,
    ensureCrossOriginIsolationHeaders: true,
    executable,
    experimentalVK: false,
    fileSizes: createGodotFileSizes(
      executable,
      mainPack,
      ENGINE_WASM_BYTES,
      GAME_PACK_BYTES
    ),
    focusCanvas: true,
    gdextensionLibs: [],
    godotPoolSize: 4,
    mainPack,
  });

  try {
    await engine.startGame({ onProgress: showDownloadProgress });
    canvas.classList.add("is-ready");
    await nextPaint();
    await nextPaint();
    runtimeState.remove();
    canvas.focus();
  } catch (runtimeError) {
    showError(
      runtimeError instanceof Error
        ? runtimeError.message
        : "The Godot runtime failed to initialize."
    );
  }
}

if (window.Engine) {
  void startEngine();
} else {
  const script = document.createElement("script");
  script.id = ENGINE_SCRIPT_ID;
  script.src = "/game/game.js";
  script.async = true;
  script.addEventListener("load", () => void startEngine(), { once: true });
  script.addEventListener(
    "error",
    () => showError("The Godot engine loader could not be downloaded."),
    { once: true }
  );
  document.head.appendChild(script);
}
