// Adapted from the supplied Proto Scroller client: original loader and title video/audio bridge.

function createGodotFileSizes(
  executable        ,
  mainPack        ,
  wasmBytes        ,
  packBytes
)                 {
  return {
    [`${executable}.wasm`]: wasmBytes,
    [mainPack]: packBytes,
  };
}

function calculateLoadingPercent(
  currentBytes        ,
  totalBytes
)                {
  if (!Number.isFinite(currentBytes) || !Number.isFinite(totalBytes)) {
    return null;
  }
  if (currentBytes < 0 || totalBytes <= 0) return null;
  return Math.min(100, Math.max(0, Math.round((currentBytes / totalBytes) * 100)));
}

function loadingStage(percent        )         {
  if (percent >= 100) return webT("web.starting");
  if (percent >= 80) return webT("web.assembling");
  return webT("web.downloading");
}

function formatDownloadSpeed(bytesPerSecond               )         {
  if (bytesPerSecond === null || !Number.isFinite(bytesPerSecond) || bytesPerSecond <= 0) {
    return webT("web.measuring");
  }
  if (bytesPerSecond >= 1_048_576) {
    return `${(bytesPerSecond / 1_048_576).toFixed(1)} MiB/s`;
  }
  if (bytesPerSecond >= 1_024) {
    return `${(bytesPerSecond / 1_024).toFixed(1)} KiB/s`;
  }
  return `${Math.round(bytesPerSecond)} B/s`;
}

function formatEta(etaSeconds               )         {
  if (etaSeconds === null || !Number.isFinite(etaSeconds) || etaSeconds < 0) {
    return webT("web.calculating");
  }
  if (etaSeconds === 0) return webT("web.ready");
  const totalSeconds = Math.max(1, Math.ceil(etaSeconds));
  if (totalSeconds < 60) return webT("web.seconds", {count: totalSeconds});
  if (totalSeconds < 3_600) {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return seconds === 0 ? webT("web.minutes", {count: minutes}) : webT("web.minutes", {count: minutes}) + " " + webT("web.seconds", {count: seconds});
  }
  const hours = Math.floor(totalSeconds / 3_600);
  const minutes = Math.ceil((totalSeconds % 3_600) / 60);
  return minutes === 0 ? webT("web.hours", {count: hours}) : webT("web.hours", {count: hours}) + " " + webT("web.minutes", {count: minutes});
}

class DownloadTelemetryTracker {
                   smoothingFactor        ;
                   minimumSampleMs        ;
          lastBytes                = null;
          lastTimestampMs                = null;
          smoothedBytesPerSecond                = null;

  constructor(smoothingFactor = 0.25, minimumSampleMs = 250) {
    this.smoothingFactor = Math.min(1, Math.max(0.01, smoothingFactor));
    this.minimumSampleMs = Math.max(0, minimumSampleMs);
  }

  sample(currentBytes        , totalBytes        , timestampMs        )                    {
    if (
      !Number.isFinite(currentBytes) ||
      !Number.isFinite(totalBytes) ||
      !Number.isFinite(timestampMs) ||
      currentBytes < 0 ||
      totalBytes <= 0
    ) {
      return { bytesPerSecond: null, etaSeconds: null };
    }

    if (
      this.lastBytes === null ||
      this.lastTimestampMs === null ||
      currentBytes < this.lastBytes ||
      timestampMs < this.lastTimestampMs
    ) {
      this.lastBytes = currentBytes;
      this.lastTimestampMs = timestampMs;
      this.smoothedBytesPerSecond = null;
      return this.currentEstimate(currentBytes, totalBytes);
    }

    const elapsedMs = timestampMs - this.lastTimestampMs;
    const downloadedBytes = currentBytes - this.lastBytes;
    if (elapsedMs >= this.minimumSampleMs && downloadedBytes > 0) {
      const instantaneousBytesPerSecond = downloadedBytes / (elapsedMs / 1_000);
      this.smoothedBytesPerSecond = this.smoothedBytesPerSecond === null
        ? instantaneousBytesPerSecond
        : this.smoothingFactor * instantaneousBytesPerSecond +
          (1 - this.smoothingFactor) * this.smoothedBytesPerSecond;
      this.lastBytes = currentBytes;
      this.lastTimestampMs = timestampMs;
    }

    return this.currentEstimate(currentBytes, totalBytes);
  }

          currentEstimate(currentBytes        , totalBytes        )                    {
    const remainingBytes = Math.max(0, totalBytes - currentBytes);
    const etaSeconds = remainingBytes === 0
      ? 0
      : this.smoothedBytesPerSecond === null || this.smoothedBytesPerSecond <= 0
        ? null
        : remainingBytes / this.smoothedBytesPerSecond;
    return {
      bytesPerSecond: this.smoothedBytesPerSecond,
      etaSeconds,
    };
  }
}

const DESKTOP_MAX_WIDTH = 1600;
const DESKTOP_MAX_HEIGHT = 900;
const PERFORMANCE_MAX_WIDTH = 1280;
const PERFORMANCE_MAX_HEIGHT = 720;

function positiveDimension(value        )         {
  if (!Number.isFinite(value)) return 1;
  return Math.max(1, value);
}

function calculateWebRenderResolution(
  cssWidth        ,
  cssHeight        ,
  devicePixelRatio        ,
  tier
)                      {
  const safeCssWidth = positiveDimension(cssWidth);
  const safeCssHeight = positiveDimension(cssHeight);
  const safeDevicePixelRatio = positiveDimension(devicePixelRatio);
  const desiredWidth = safeCssWidth * safeDevicePixelRatio;
  const desiredHeight = safeCssHeight * safeDevicePixelRatio;
  const landscapeMaxWidth =
    tier === "performance" ? PERFORMANCE_MAX_WIDTH : DESKTOP_MAX_WIDTH;
  const landscapeMaxHeight =
    tier === "performance" ? PERFORMANCE_MAX_HEIGHT : DESKTOP_MAX_HEIGHT;
  const portrait = safeCssHeight > safeCssWidth;
  const maxWidth = portrait ? landscapeMaxHeight : landscapeMaxWidth;
  const maxHeight = portrait ? landscapeMaxWidth : landscapeMaxHeight;
  const scale = Math.min(1, maxWidth / desiredWidth, maxHeight / desiredHeight);

  return {
    cssWidth: safeCssWidth,
    cssHeight: safeCssHeight,
    devicePixelRatio: safeDevicePixelRatio,
    width: Math.max(1, Math.round(desiredWidth * scale)),
    height: Math.max(1, Math.round(desiredHeight * scale)),
    tier,
  };
}

function selectWebRenderTier(
  requestedTier               ,
  touchPoints
)                {
  if (requestedTier === "performance") return "performance";
  if (requestedTier === "desktop") return "desktop";
  return touchPoints > 0 ? "performance" : "desktop";
}

const ENGINE_SCRIPT_ID = "proto-scroller-godot-engine";
const ENGINE_WASM_BYTES = GODOT_CONFIG.fileSizes[GODOT_CONFIG.executable + '.wasm'] || 0;
const GAME_PACK_BYTES = GODOT_CONFIG.fileSizes[GODOT_CONFIG.mainPack || GODOT_CONFIG.executable + '.pck'] || 0;
const SLOW_LOAD_NOTICE_MS = 15_000;
const RETRY_NOTICE_MS = 45_000;
const searchParameters = new URLSearchParams(window.location.search);
const root = document.getElementById("root");

if (!root) {
  throw new Error("Missing game root element.");
}

root.innerHTML = `
  <main class="game-host">
    <picture id="title-poster-backdrop" class="title-poster-backdrop" aria-hidden="true">
      <source media="(orientation: portrait)" srcset="__TITLE_ASSETS__/title-poster-portrait.jpg" />
      <img src="__TITLE_ASSETS__/title-poster-landscape.jpg" alt="" />
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
      <source media="(orientation: portrait)" src="__TITLE_ASSETS__/title-loop-portrait.mp4" type="video/mp4" />
      <source src="__TITLE_ASSETS__/title-loop-landscape.mp4" type="video/mp4" />
    </video>
    <canvas id="canvas" class="game-canvas" tabindex="0" aria-label="Proto Scroller">
      ${webT("web.canvas")}
    </canvas>
    <section id="runtime-state" class="runtime-state" role="status" aria-live="polite">
      <div class="loader-console">
        <p class="loader-kicker">${webT("web.kicker")}</p>
        <p id="loader-stage" class="loader-stage">${webT("web.preparing")}</p>
        <div class="loader-progress-row">
          <progress id="loader-progress" class="loader-progress" max="100"></progress>
          <span id="loader-percent" class="loader-percent">${webT("web.connecting")}</span>
        </div>
        <dl class="loader-telemetry" aria-label="${webT('web.telemetry')}">
          <div class="loader-telemetry-item">
            <dt>${webT("web.speed")}</dt>
            <dd id="loader-speed">${webT("web.measuring")}</dd>
          </div>
          <div class="loader-telemetry-item">
            <dt>${webT("web.eta")}</dt>
            <dd id="loader-eta">${webT("web.calculating")}</dd>
          </div>
        </dl>
        <p id="loader-detail" class="loader-detail">${webT("web.loading")}</p>
        <button id="loader-retry" class="loader-retry" type="button" hidden>${webT("web.retry_download")}</button>
      </div>
    </section>
  </main>
`;

function requireElement                       (id        )    {
  const element = document.getElementById(id);
  if (!element) throw new Error(`Missing loader element: ${id}`);
  return element     ;
}

const canvas = requireElement                   ("canvas");
const titleVideoBackdrop = requireElement                  (
  "title-video-backdrop"
);
const TITLE_VIDEO_LANDSCAPE = "__TITLE_ASSETS__/title-loop-landscape.mp4";
const TITLE_VIDEO_PORTRAIT = "__TITLE_ASSETS__/title-loop-portrait.mp4";
const TITLE_IMPACT_SECONDS                                             = {
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

const trackedAudioContexts = new Set                     ();
let titleSourceLocked = false;
// Preserve the first-interaction audio unlock from the original direct-export shell.
window.protoScrollerResumeTitleAudio = function () {
  const contexts = [...trackedAudioContexts];
  const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__ =
    window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__ || {
      sourceKind: 'title-lifecycle-queued', committed: false, commitStatus: 'queued-at-title'
    };
  Promise.all(contexts.map(context => context.resume())).then(() => {
    Object.assign(telemetry, {
      audioContextState: contexts.find(context => context.state === 'running')?.state || 'unavailable',
      committed: true, commitStatus: 'title-interaction-resumed'
    });
  }).catch(() => Object.assign(telemetry, {
    fallback: true, fallbackReason: 'title-interaction-resume-rejected', commitStatus: 'resume-rejected'
  }));
  return contexts.length > 0;
};
let lockedTitleOrientation                          = null;
let titleScheduleGeneration = 0;
let titleScheduleFrame = 0;
let titleScheduleTimer = 0;
let titleTargetOutputPerformanceTime = 0;
let pendingSourceCapture

             ;

function selectedTitleOrientation()                   {
  if (titleSourceLocked && lockedTitleOrientation)
    return lockedTitleOrientation;
  return window.matchMedia("(orientation: portrait)").matches
    ? "portrait"
    : "landscape";
}
function titleSourceFor(orientation                  )         {
  return orientation === "portrait"
    ? TITLE_VIDEO_PORTRAIT
    : TITLE_VIDEO_LANDSCAPE;
}
function selectTitleVideoSource(force = false)       {
  if (titleSourceLocked && !force) return;
  const source = titleSourceFor(selectedTitleOrientation());
  const currentPath = new URL(
    titleVideoBackdrop.currentSrc || titleVideoBackdrop.src || source,
    location.href
  ).pathname;
  if (currentPath === new URL(source, location.href).pathname && !force) return;
  const shouldPlay =
    !titleVideoBackdrop.paused ||
    document.body.classList.contains("title-backdrop-active");
  titleVideoBackdrop.src = source;
  titleVideoBackdrop.load();
  if (shouldPlay) void titleVideoBackdrop.play().catch(() => undefined);
}
function boundedOutputLatency(context                     )         {
  return Math.min(
    Math.max(context.outputLatency || context.baseLatency || 0, 0),
    TITLE_AUDIO_MAX_OUTPUT_LATENCY_SECONDS
  );
}
function outputPerformanceTime(
  context                     ,
  scheduledContextTime
)         {
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
function bufferContainsSignal(buffer                    )          {
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
function installAudioContextTracking()       {
  const scope = window

     ;
  const NativeAudioContext = scope.AudioContext ?? scope.webkitAudioContext;
  if (!NativeAudioContext) return;
  const marker = NativeAudioContext

   ;
  if (marker.__protoScrollerWrapped) return;
  const WrappedAudioContext = class extends NativeAudioContext {
    constructor(options                      ) {
      super(options);
      trackedAudioContexts.add(this);
    }
  };
  (
    WrappedAudioContext

  ).__protoScrollerWrapped = true;
  scope.AudioContext = WrappedAudioContext;
  if (scope.webkitAudioContext) scope.webkitAudioContext = WrappedAudioContext;
}
function installAudioBufferSourceStartProbe()       {
  const prototype = window.AudioBufferSourceNode?.prototype

               ;
  if (!prototype || prototype.__protoScrollerStartWrapped) return;
  const nativeStart = prototype.start;
  prototype.start = function start(
    when = 0,
    offset = 0,
    duration
  )       {
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
      const context = this.context                       ;
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
  orientation                  ,
  trusted
)                          {
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
  generation        ,
  calibrationCallback
)       {
  if (generation === titleScheduleGeneration) calibrationCallback?.("complete");
}
function commitTitleMusic(
  generation        ,
  commitCallback                              ,
  calibrationCallback                               ,
  fallbackReason
)       {
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
  generation        ,
  commitCallback                              ,
  calibrationCallback
)                {
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
    await new Promise      (resolve => requestAnimationFrame(() => resolve()));
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
  const sample = ()       => {
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
const runtimeState = requireElement             ("runtime-state");
const loaderStage = requireElement             ("loader-stage");
const loaderProgress = requireElement                     ("loader-progress");
const loaderPercent = requireElement             ("loader-percent");
const loaderSpeed = requireElement             ("loader-speed");
const loaderEta = requireElement             ("loader-eta");
const loaderDetail = requireElement             ("loader-detail");
const loaderRetry = requireElement                   ("loader-retry");
const renderTier = selectWebRenderTier(
  searchParameters.get("renderTier"),
  navigator.maxTouchPoints
);
let resizeFrame = 0;
let loadingComplete = false;
let latestPercent                = null;
const downloadTelemetry = new DownloadTelemetryTracker();

window.protoScrollerSetTitleBackdropActive = (active         )       => {
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

loaderRetry.addEventListener("click", () => window.location.reload());

function updateCanvasResolution()       {
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

function queueCanvasResolutionUpdate()       {
  window.cancelAnimationFrame(resizeFrame);
  resizeFrame = window.requestAnimationFrame(updateCanvasResolution);
}

function formatMebibytes(bytes        )         {
  return `${(bytes / 1_048_576).toFixed(1)} MiB`;
}

function showDownloadProgress(current        , total        )       {
  const percent = calculateLoadingPercent(current, total);
  const telemetry = downloadTelemetry.sample(current, total, performance.now());
  latestPercent = percent;
  if (percent === null) {
    loaderProgress.removeAttribute("value");
    loaderPercent.textContent = webT("web.connecting");
    loaderSpeed.textContent = webT("web.measuring");
    loaderEta.textContent = webT("web.calculating");
    return;
  }

  loaderProgress.value = percent;
  loaderPercent.textContent = `${percent}%`;
  loaderSpeed.textContent = formatDownloadSpeed(telemetry.bytesPerSecond);
  loaderEta.textContent = formatEta(telemetry.etaSeconds);
  loaderStage.textContent = loadingStage(percent);
  loaderDetail.textContent = `${formatMebibytes(current)} / ${formatMebibytes(total)}`;
}

function showError(message        )       {
  console.error(message);
  runtimeState.classList.add("is-error");
  loaderStage.textContent = webT("web.failed");
  loaderPercent.textContent = webT("web.offline");
  loaderSpeed.textContent = "—";
  loaderEta.textContent = webT("web.retry");
  loaderDetail.textContent = message;
  loaderProgress.hidden = true;
  loaderRetry.hidden = false;
}

function nextPaint()                {
  return new Promise(resolve => window.requestAnimationFrame(() => resolve()));
}

updateCanvasResolution();
window.addEventListener("resize", queueCanvasResolutionUpdate, {
  passive: true,
});

const slowLoadTimer = window.setTimeout(() => {
  if (loadingComplete) return;
  loaderDetail.textContent =
    latestPercent === null
      ? webT("web.cold")
      : webT("web.initializing", {percent: loaderPercent.textContent, size: formatMebibytes(ENGINE_WASM_BYTES + GAME_PACK_BYTES)});
}, SLOW_LOAD_NOTICE_MS);

const retryTimer = window.setTimeout(() => {
  if (loadingComplete) return;
  loaderDetail.textContent =
    webT("web.slow");
  loaderRetry.hidden = false;
}, RETRY_NOTICE_MS);

async function startEngine()                {
  const Engine = window.Engine;
  if (!Engine) return;

  const missing = Engine.getMissingFeatures({ threads: false });
  if (missing.length > 0) {
    showError(webT("web.missing", {features: missing.join(", ")}));
    return;
  }

  const engine = new Engine({ ...GODOT_CONFIG, canvas, canvasResizePolicy: 0 });

  loaderStage.textContent = webT("web.downloading");
  loaderDetail.textContent = webT("web.download_pack");

  try {
    await engine.startGame({ onProgress: showDownloadProgress });
    loadingComplete = true;
    window.clearTimeout(slowLoadTimer);
    window.clearTimeout(retryTimer);
    loaderStage.textContent = webT("web.starting");
    loaderPercent.textContent = "100%";
    loaderSpeed.textContent = webT("web.complete");
    loaderEta.textContent = webT("web.ready");
    loaderProgress.value = 100;
    loaderDetail.textContent = webT("web.runtime_ready");
    canvas.classList.add("is-ready");
    await nextPaint();
    await nextPaint();
    runtimeState.remove();
    canvas.focus();
  } catch (runtimeError) {
    console.error(runtimeError);
    showError(webT("web.runtime_error"));
  }
}

if (window.Engine) {
  void startEngine();
} else {
  const script = document.createElement("script");
  script.id = ENGINE_SCRIPT_ID;
  script.src = GODOT_SCRIPT_URL;
  script.async = true;
  script.addEventListener("load", () => void startEngine(), { once: true });
  script.addEventListener(
    "error",
    () => showError(webT("web.engine_error")),
    { once: true }
  );
  document.head.appendChild(script);
}
