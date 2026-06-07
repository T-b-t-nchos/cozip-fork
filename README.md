<div align="center">
<h2>CoZip</h2>
<p>GPU-accelerated compression/decompression tools and libraries</p>
</div>

<a href="https://discord.gg/F9DfEw6fqX" data-size="large">
  <img alt="Discord" src="https://img.shields.io/discord/1481785335519117316.svg?label=Discord&logo=Discord&colorB=7289da&style=for-the-badge">
</a>

- `cozip_deflate`: custom frame format (`CZDF`) with CPU/GPU-assisted **compression** and CPU **decompression**.
- `cozip_pdeflate`: native PDeflate implementation with low-level stream/file APIs and parallel read/write paths.
- `cozip`: ZIP/PDeflate wrapper-orchestrator for file and directory compression APIs.
- `cozip_desktop`: GPUI-based desktop application.

日本語: [README.ja.md](./README.ja.md)

## Workspace Layout

```
cozip/
  src/
    cozip_deflate/
    cozip_pdeflate/
    cozip/
    cozip_desktop/
  bench.sh
  docs/
```

## Build

```bash
cargo check --workspace
cargo test --workspace
```

> Note: several GPU tests share the host GPU. Running the whole workspace test in
> parallel can flake under GPU contention; run per crate (e.g. `cargo test -p cozip`)
> for stable results.

## Linux desktop integration

`packaging/linux/install.sh` installs the desktop entry, MIME type, KDE/Dolphin
service menus, and right-click "Scripts" entries for GNOME (Nautilus), Cinnamon
(Nemo) and MATE (Caja). `packaging/linux/uninstall.sh` removes them.

```bash
./packaging/linux/install.sh          # build + install for the current user
./packaging/linux/uninstall.sh
```

On GNOME/Cinnamon/MATE the compress/extract actions appear under the right-click
**Scripts** submenu. Non-UTF-8 (e.g. Shift-JIS) file names produced on Windows are
decoded on extraction and re-encoded as UTF-8 on creation, matching Windows behavior.

## GPU kill switch

Set `COZIP_DISABLE_GPU=1` to force CPU-only operation. This is the cross-platform
escape hatch for headless servers, broken GPU drivers, or CI; compression falls back
to the CPU path transparently.

## Custom-format compression ratio (Huffman)

The PDeflate (`CoZip`) format applies an optional per-chunk canonical-Huffman entropy
stage after match-finding. It is **backward compatible** (the flag is per-chunk; older
streams keep decoding) and **on by default**: each chunk is Huffman-coded only when the
estimated saving clears a threshold, so incompressible/marginal data keeps the fast path
and the GPU-accelerated match stage is unaffected, while skewed data shrinks noticeably
(~8–17% smaller on biased literal data in local measurements). GPU decompression
decodes Huffman chunks directly.

## `cozip_desktop` Arguments

Running `cozip_desktop` without arguments opens the desktop application on the
compress screen.

```bash
cozip_desktop
```

Supported command forms:

```bash
cozip_desktop compress [--format zip|cozip] [--hybrid] <path>...
cozip_desktop extract --here <archive-or-directory>...
cozip_desktop ui compress-details [--format zip|cozip] [--hybrid] <path>...
cozip_desktop ui extract-details <archive-or-directory>...
```

Argument details:

- `compress`: builds a compression plan and starts it immediately.
- `extract`: builds an extraction plan and starts it immediately. `--here` is currently required for this auto-start path.
- `ui compress-details`: opens the compression settings screen with the selected paths preloaded.
- `ui extract-details`: opens the extraction settings screen with the selected archives preloaded.
- `--format zip|cozip`: selects the output archive format for compression. The default is `zip`.
- `--hybrid`: requests hybrid CPU/GPU deflate mode for ZIP compression. It is accepted for CoZip/PDeflate commands, but currently only changes ZIP options.
- `<path>...`: one or more files or directories for compression.
- `<archive-or-directory>...`: one or more archives, or directories containing supported archives, for extraction.

## `cozip_deflate` Quick Use

```rust
use cozip_deflate::{CoZipDeflate, HybridOptions};

let options = HybridOptions::default();
let cozip = CoZipDeflate::init(options)?;

let compressed = cozip.compress(input_bytes)?;
let decompressed = cozip.decompress_on_cpu(&compressed.bytes)?;
assert_eq!(decompressed.bytes, input_bytes);
# Ok::<(), cozip_deflate::CozipDeflateError>(())
```

Main public helpers:

- `compress_hybrid(...)`
- `decompress_on_cpu(...)`
- `compress_stream(...)`
- `decompress_stream(...)`
- `CoZipDeflate::compress_file(...)`
- `CoZipDeflate::decompress_file(...)`
- `CoZipDeflate::compress_file_from_name(...)`
- `CoZipDeflate::decompress_file_from_name(...)`
- `CoZipDeflate::compress_file_async(...)`
- `CoZipDeflate::decompress_file_async(...)`
- `deflate_compress_cpu(...)`
- `deflate_decompress_on_cpu(...)`

Streaming API for large files (bounded memory, avoids reading full file into RAM):

```rust
use cozip_deflate::{CoZipDeflate, HybridOptions, StreamOptions};
use std::fs::File;

let cozip = CoZipDeflate::init(HybridOptions::default())?;
let input = File::open("huge-input.bin")?;
let output = File::create("huge-output.czds")?;
let stats = cozip.compress_file(input, output, StreamOptions { frame_input_size: 64 * 1024 * 1024 })?;

let compressed = File::open("huge-output.czds")?;
let restored = File::create("restored.bin")?;
let _ = cozip.decompress_file(compressed, restored)?;
println!("frames={}", stats.frames);
# Ok::<(), cozip_deflate::CozipDeflateError>(())
```

## `cozip` Quick Use

```rust
use cozip::{CoZip, CoZipOptions, ZipOptions};

let cozip = CoZip::init(CoZipOptions::Zip {
    options: ZipOptions::default(),
});

// Single file (path-based)
let _ = cozip.compress_file_from_name("input.txt", "single.zip")?;

// Directory (async API)
# async fn run() -> Result<(), cozip::CoZipError> {
let _ = cozip
    .compress_directory_async("assets/", "assets.zip")
    .await?;
# Ok(())
# }
# Ok::<(), cozip::CoZipError>(())
```

You can also select the PDeflate backend directly.

```rust
use cozip::{CoZip, CoZipOptions, PDeflateOptions};

let cozip = CoZip::init(CoZipOptions::PDeflate {
    options: PDeflateOptions::default(),
});

let _ = cozip.compress_file_from_name("input.bin", "input.cozip")?;
# Ok::<(), cozip::CoZipError>(())
```

PDeflate backend also supports directory mode. In that case `cozip` first packs the directory into an internal streaming archive and then applies PDeflate compression, similar to `tar.gz`'s `archive -> compress` order. `decompress_auto*` also detects this archive form and routes to directory extraction automatically.

### Important `cozip` APIs added or updated recently

- `decompress_auto(...)`
- `decompress_auto_from_name(...)`
- `decompress_file_with_progress(...)`
- `decompress_directory_with_progress(...)`
- `decompress_file_with_progress_and_expected_output_bytes(...)`
- `decompress_file_from_name_with_progress_and_expected_output_bytes(...)`
- `inspect_archive_from_name(...)`
- `inspect_archive_decode_hint_from_name(...)`
- `CoZipProgress`
- `CoZipArchiveInfo`
- `ZipOptions { parallel_read_threads, parallel_write_threads, deflate_mode, ... }`
- `PDeflateOptions { parallel_read_threads, parallel_write_threads, gpu_* , ... }`

The most practical additions are:

- `decompress_auto*`
  - auto-detects ZIP/PDeflate and single-file/directory archives.
- `CoZipProgress`
  - exposes progress, current entry, total bytes, and throughput for GUI/CLI integration.
- `inspect_archive_*`
  - lets you inspect archive format, kind, and parallel-decode hints before extraction.

### Main `cozip_pdeflate` APIs

- `compress_stream_with_options(...)`
- `decompress_stream_with_options(...)`
- `compress_file_with_options(...)`
- `compress_file_parallel_read_with_options(...)`
- `decompress_file_parallel_write_with_options(...)`
- `pdeflate_stream_suggested_name(...)`
- `pdeflate_stream_uncompressed_size(...)`

## Benchmark

Run process-restart benchmark from repository root:

```bash
./bench.sh --mode ratio --runs 5
```

Notes:

- `speedup(cpu/hybrid)` is reported for **compression**.
- Decompression speedup is intentionally omitted/deprecated because decompression is CPU-only now.

## Additional Docs

- [`docs/context-log.md`](./docs/context-log.md): implementation history and experiment notes.
- [`docs/gpu-deflate-chunk-pipeline.md`](./docs/gpu-deflate-chunk-pipeline.md): GPU deflate pipeline notes.
- [`docs/pdeflate-v0-spec.md`](./docs/pdeflate-v0-spec.md): single source of truth for the current PDeflate v0 format.
- [`docs/pdeflate-v0-baseline.md`](./docs/pdeflate-v0-baseline.md): fixed benchmark command and implementation baseline metrics.
