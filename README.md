# MiniMax H3 · M1 Pro 32GB

最小实现：`init.sh` 安装环境、节点和基础模型，`run.sh` 启动 ComfyUI。ComfyUI、虚拟环境、模型与输出都放在当前项目下。首次导入后在界面保存自己的工作流，后续直接运行。

## 1. 初始化

需要原生 arm64 终端、macOS 14+ 和 [Homebrew](https://brew.sh)。在项目目录执行：

```bash
./init.sh
```

安装和模型下载统一沿用当前环境的网络配置，脚本不设置、清除或检测代理。Git、pip 和 hf 按各自默认方式读取代理配置；命令行工具不一定自动读取 macOS 系统设置中的代理，但会继承终端已有的代理环境变量。

默认安装 Homebrew Python 3.14 的当前补丁版（常规 GIL 版本）、Git、ComfyUI v0.34.0、PyTorch 2.14.0，以及 MacMax 的全部节点。前端版本遵循 ComfyUI 自带的 `requirements.txt`（v0.34.0 指定 1.49.6）。脚本仅执行安装、下载和启动；保留已有目录复用及命令失败即停止，省去系统、架构、Homebrew、依赖、MPS 运算及启动前文件检查。下载模型：

| 模型 | `ComfyUI/models/` 下的路径 |
| --- | --- |
| Q4 视频模型 | `diffusion_models/MiniMax-H3-FL2VA-Pruned-Q4_K_M.gguf` |
| 4B 编码器 | `text_encoders/qwen3vl_4b_fp8_scaled.safetensors` |
| 投影矩阵 | `clip_projections/mmh3-4b-ClipProj-v3.1.safetensors` |
| 视频 VAE | `vae/minimax_h3_video_vae_fp16.safetensors` |
| 音频 VAE | `vae/minimax_h3_audio_vae_fp32.safetensors` |
| Parasyte Turbo LoRA | `loras/H3-PK-Parasyte-Turbo.safetensors` |

LoRA 同样由初始化脚本下载，来源为 `Plaguekind/H3-Lora`。如果在 ComfyUI 启动后才下载模型，重启后重新选择模型文件。

模型需要数十 GB 磁盘空间，另需为依赖、下载缓存、输出和系统交换内存留出空间。下载中断后可重跑初始化；已有仓库和虚拟环境会复用，Hugging Face CLI 会复用已完成的下载。不要在 ComfyUI 运行或生成期间执行初始化。

若下载返回 401/403，先在对应 Hugging Face 仓库网页确认授权、接受许可，再登录并重跑：

```bash
./ComfyUI/venv/bin/hf auth login
./init.sh
```

## 2. 启动

```bash
./run.sh
```

打开 [ComfyUI](http://127.0.0.1:8288)。终端需保持运行，`Ctrl+C` 停止；输出位于 `ComfyUI/output/`。启动参数使用 `ASFP8_INT8_EXT=1`、预留 1GB、关闭缓存和 smart memory。可追加 ComfyUI 参数，例如 `./run.sh --preview-method none`。

## 3. 首次配置工作流

将项目根目录的 `workflow-m1pro-32gb.json` 拖入 ComfyUI。该副本已切换至 Q4 + 4B ClipProj（CPU），替换了两个条件节点的 CLIP 连接，旁路原 32B 编码器，并设置约 1 秒时长及简单试跑提示词。下载 LoRA 后重启 ComfyUI，再导入试跑；该副本已检查连线，尚未完成实际生成验证。

如果选择导入上游原版 `minimax-h3-mac/MacMax_MiniMaxH3_AppleSilicon.json`，它仍是 Q5 + 32B 配置，需要手动按下表修改：

| 节点或设置 | 值或操作 |
| --- | --- |
| GGUF 视频模型加载器 | `MiniMax-H3-FL2VA-Pruned-Q4_K_M.gguf` |
| GGUF 的 LoRA GPU 补丁选项 | 保持关闭 |
| ClipProj Loader | 取消 Bypass，启用 |
| ClipProj 编码器 | `qwen3vl_4b_fp8_scaled.safetensors` |
| ClipProj 编码器类型 | `auto`（或 `krea2`）；4B 编码器不要选 `minimax` |
| ClipProj 投影 | `mmh3-4b-ClipProj-v3.1.safetensors` |
| ClipProj 加载设备 | `cpu` |
| 原始 32B GGUF 文本编码器 | Bypass / 禁用 |
| ClipProj 的 CLIP 输出 | 接到提示词编码节点的 `clip` 输入，替换原 32B 连接；若有多个提示词编码节点，都要替换 |
| 两个 VAE 加载器 | 分别选择上表对应 VAE |
| Parasyte Turbo | 启用，选择 `H3-PK-Parasyte-Turbo.safetensors`，强度 1.5 |
| Parasyte 后的 AdaLN 兼容节点 | 保持启用，`strip` |
| 采样 | 8 步，ER-SDE / beta57，denoise 1，视频/音频 shift 12/3 |

先尝试 352×608、约 1 秒、batch 1 的短片，跑通后逐步增加时长。首次保持图片、R2V、Motion Context 等可选分支旁路。检查终端是否出现 `IMPORT FAILED`，并确认提示词实际使用 ClipProj 分支。该 Q4 + 4B 配置在本项目尚未完成 M1 Pro 32GB 实测，不保证长片或原生 1080p 能运行；可选 1080p 导出只是像素缩放。

## 兼容性

[ComfyUI 官方说明](https://github.com/Comfy-Org/ComfyUI#manual-install-windows-linux)支持 Python 3.14，但提示部分自定义节点可能有问题；[PyTorch 2.14.0](https://pypi.org/project/torch/2.14.0/)提供 Python 3.14 / macOS 14+ arm64 安装包。Python 3.14 是本项目默认尝试版本，并非 MacMax 完整验证版本。

如果自定义节点在 3.14 上安装失败，优先参照 [MacMax 版本验证记录](https://github.com/Bambushu/minimax-h3-mac/blob/master/RELEASE_VALIDATION.md)：其干净安装使用 Python 3.12、ComfyUI v0.34.0、PyTorch 2.14.0、前端 1.51.9。停止 ComfyUI 后保留旧环境并重建：

```bash
mv ComfyUI/venv ComfyUI/venv-python314-backup
PYTHON_VERSION=3.12 ./init.sh
```

已有环境会被复用，因此只设置 `PYTHON_VERSION` 不会改变已有 venv 的 Python。`requirements-mac.txt` 仅约束 PyTorch；前端版本遵循 ComfyUI 的依赖要求，上述验证记录中的 1.51.9 不作为安装约束。节点版本由上游安装脚本管理；其余依赖不做完整锁定。兼容性问题应结合验证记录检查节点 revision；不要在 Mac 上安装 CUDA、xformers 或 NVIDIA 专用依赖。
