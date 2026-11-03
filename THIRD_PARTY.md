# 第三方依赖

本项目依赖 Efinix Titanium IP（FIFO、CSI/DSI、DDR 等）、VF-Ti60F225 板级采集/HDMI/接口示例，以及中文显示字体。

本地 Efinix 生成代码带有 Copyright (C) Efinix Inc.、All rights reserved 和 proprietary information 声明。板卡例程中还有第三方作者标记。未取得明确再分发许可的文件不随本仓库公开。

`dependencies/manifest.json` 记录依赖的相对路径及摘要，不包含它们的源码。`project_changes.json` 只记录本项目的局部替换，应用前校验厂商基础文件摘要；它不向使用者授予基础文件的权利。

MIT 许可仅覆盖本仓库中的项目自有部分，不适用于工具安装包、开发工具许可文件、导入的厂商源码、字体、板级集成依赖或厂商手册。恢复工具写入的依赖已在 `.gitignore` 中排除，请勿通过 `git add -f` 再发布它们。

中文字模未分发。重新生成时请使用自己有权使用的字体，并遵守其输出与嵌入条款。
