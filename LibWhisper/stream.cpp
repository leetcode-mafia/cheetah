// This code is based on the streaming example provided with whisper.cpp:
// https://github.com/ggerganov/whisper.cpp/blob/ca21f7ab16694384fb74b1ba4f68b39f16540d23/examples/stream/stream.cpp

#include "common.h"
#include "common-sdl.h"
#include "whisper.h"
#include "stream.h"

#include <cassert>
#include <cstdio>
#include <string>
#include <thread>
#include <vector>
#include <fstream>

using unique_whisper = std::unique_ptr<whisper_context, std::integral_constant<decltype(&whisper_free), &whisper_free>>;

struct stream_context {
    stream_params params;
    std::unique_ptr<audio_async> audio;
    unique_whisper whisper;
    std::vector<float> pcmf32;
    std::vector<float> pcmf32_old;
    std::vector<float> pcmf32_new;
    std::vector<whisper_token> prompt_tokens;
    std::chrono::time_point<std::chrono::high_resolution_clock> t_last;
    std::chrono::time_point<std::chrono::high_resolution_clock> t_start;
    int n_samples_step;
    int n_samples_len;
    int n_samples_keep;
    bool use_vad;
    int n_new_line;
    int n_iter = 0;
};

struct stream_params stream_default_params() {
    return stream_params {
        /* .n_threads     =*/ std::min(4, (int32_t) std::thread::hardware_concurrency()),
        /* .step_ms       =*/ 3000,
        /* .length_ms     =*/ 10000,
        /* .keep_ms       =*/ 200,
        /* .capture_id    =*/ -1,
        /* .max_tokens    =*/ 32,
        /* .audio_ctx     =*/ 0,

        /* .vad_thold     =*/ 0.6f,
        /* .freq_thold    =*/ 100.0f,

        /* .speed_up      =*/ false,
        /* .translate     =*/ false,
        /* .print_special =*/ false,
        /* .no_context    =*/ true,
        /* .no_timestamps =*/ false,

        /* .language      =*/ "en",
        /* .model         =*/ "models/ggml-base.en.bin"
    };
}

stream_context *stream_init(stream_params params) {
    auto ctx = std::make_unique<stream_context>();

    params.keep_ms = std::min(params.keep_ms, params.step_ms);
    params.length_ms = std::max(params.length_ms, params.step_ms);

    ctx->n_samples_step = (1e-3 * params.step_ms) * WHISPER_SAMPLE_RATE;
    ctx->n_samples_len = (1e-3 * params.length_ms) * WHISPER_SAMPLE_RATE;
    ctx->n_samples_keep = (1e-3 * params.keep_ms) * WHISPER_SAMPLE_RATE;
    const int n_samples_30s = (1e-3 * 30000.0) * WHISPER_SAMPLE_RATE;

    ctx->use_vad = ctx->n_samples_step <= 0; // sliding window mode uses VAD

    ctx->n_new_line = !ctx->use_vad ? std::max(1, params.length_ms / params.step_ms - 1) : 1; // number of steps to print new line

    params.no_timestamps = !ctx->use_vad;
    params.no_context |= ctx->use_vad;
    params.max_tokens = 0;

    // init audio
    ctx->audio = std::make_unique<audio_async>(params.length_ms);
    if (!ctx->audio->init(params.capture_id, WHISPER_SAMPLE_RATE)) {
        fprintf(stderr, "%s: audio.init() failed!\n", __func__);
        return NULL;
    }

    ctx->audio->resume();

    // whisper init
    if (whisper_lang_id(params.language) == -1) {
        fprintf(stderr, "%s: unknown language '%s'\n", __func__, params.language);
        return NULL;
    }

    if ((ctx->whisper = unique_whisper(whisper_init_from_file(params.model))) == NULL) {
        return NULL;
    }

    ctx->pcmf32 = std::vector<float>(n_samples_30s, 0.0f);
    ctx->pcmf32_new = std::vector<float>(n_samples_30s, 0.0f);

    ctx->t_last = std::chrono::high_resolution_clock::now();
    ctx->t_start = ctx->t_last;

    ctx->params = params;

    return ctx.release();
}

void stream_free(stream_context *ctx) {
    ctx->audio = NULL;
    ctx->whisper = NULL;
    ctx->pcmf32.clear();
    ctx->pcmf32_old.clear();
    ctx->pcmf32_new.clear();
    ctx->prompt_tokens.clear();
}

int stream_run(stream_context *ctx, void *callback_ctx, stream_callback_t callback) {
    auto params = ctx->params;
    auto whisper = ctx->whisper.get();

    auto t_now = std::chrono::high_resolution_clock::now();

    if (!ctx->use_vad) {
        while (true) {
            ctx->audio->get(params.step_ms, ctx->pcmf32_new);

            if ((int)ctx->pcmf32_new.size() > 2 * ctx->n_samples_step) {
                fprintf(stderr, "\n\n%s: WARNING: cannot process audio fast enough, dropping audio ...\n\n", __func__);
                ctx->audio->clear();
                continue;
            }

            if ((int)ctx->pcmf32_new.size() >= ctx->n_samples_step) {
                ctx->audio->clear();
                break;
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }

        const int n_samples_new = ctx->pcmf32_new.size();

        // take up to params.length_ms audio from previous iteration
        const int n_samples_take = std::min((int)ctx->pcmf32_old.size(), std::max(0, ctx->n_samples_keep + ctx->n_samples_len - n_samples_new));

        ctx->pcmf32.resize(n_samples_new + n_samples_take);

        for (int i = 0; i < n_samples_take; i++) {
            ctx->pcmf32[i] = ctx->pcmf32_old[ctx->pcmf32_old.size() - n_samples_take + i];
        }

        memcpy(ctx->pcmf32.data() + n_samples_take, ctx->pcmf32_new.data(), n_samples_new * sizeof(float));

        ctx->pcmf32_old = ctx->pcmf32;
    } else {
        auto t_diff = std::chrono::duration_cast<std::chrono::milliseconds>(t_now - ctx->t_last).count();
        if (t_diff < 2000) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            return 0;
        }
        
        // process new audio
        ctx->audio->get(2000, ctx->pcmf32_new);
        
        if (::vad_simple(ctx->pcmf32_new, WHISPER_SAMPLE_RATE, 1000, params.vad_thold, params.freq_thold, false)) {
            ctx->audio->get(params.length_ms, ctx->pcmf32);
        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            return 0;
        }
        
        ctx->t_last = t_now;
    }

    // run the inference
    whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

    wparams.print_progress = false;
    wparams.print_special = params.print_special;
    wparams.print_realtime = false;
    wparams.print_timestamps = !params.no_timestamps;
    wparams.translate = params.translate;
    wparams.no_context = true;
    wparams.single_segment = !ctx->use_vad;
    wparams.max_tokens = params.max_tokens;
    wparams.language = params.language;
    wparams.n_threads = params.n_threads;

    wparams.audio_ctx = params.audio_ctx;
    wparams.speed_up = params.speed_up;

    // disable temperature fallback
    wparams.temperature_inc = -1.0f;

    wparams.prompt_tokens = params.no_context ? nullptr : ctx->prompt_tokens.data();
    wparams.prompt_n_tokens = params.no_context ? 0 : ctx->prompt_tokens.size();

    const int64_t t1 = (t_now - ctx->t_start).count() / 1000000;
    const int64_t t0 = std::max(0.0, t1 - ctx->pcmf32.size() * 1000.0 / WHISPER_SAMPLE_RATE);

    if (whisper_full(whisper, wparams, ctx->pcmf32.data(), ctx->pcmf32.size()) != 0) {
        fprintf(stderr, "%s: failed to process audio\n", __func__);
        return 6;
    }

    const int n_segments = whisper_full_n_segments(whisper);
    for (int i = 0; i < n_segments; ++i) {
        const char *text = whisper_full_get_segment_text(whisper, i);

        const int64_t segment_t0 = whisper_full_get_segment_t0(whisper, i);
        const int64_t segment_t1 = whisper_full_get_segment_t1(whisper, i);

        callback(text, ctx->use_vad ? segment_t0 : t0, ctx->use_vad ? segment_t1 : t1, callback_ctx);
    }

    ++ctx->n_iter;

    if (!ctx->use_vad && (ctx->n_iter % ctx->n_new_line) == 0) {
        callback(NULL, 0, 0, callback_ctx);

        // keep part of the audio for next iteration to try to mitigate word boundary issues
        ctx->pcmf32_old = std::vector<float>(ctx->pcmf32.end() - ctx->n_samples_keep, ctx->pcmf32.end());

        // Add tokens of the last full length segment as the prompt
        if (!params.no_context) {
            ctx->prompt_tokens.clear();

            const int n_segments = whisper_full_n_segments(whisper);
            for (int i = 0; i < n_segments; ++i) {
                const int token_count = whisper_full_n_tokens(whisper, i);
                for (int j = 0; j < token_count; ++j) {
                    ctx->prompt_tokens.push_back(whisper_full_get_token_id(whisper, i, j));
                }
            }
        }
    }

    return 0;
}
