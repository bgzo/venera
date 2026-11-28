# Venera Fork‘s Fork

个人使用的 Venera 分支，基于 [haukuen/venera](https://github.com/haukuen/venera)，原项目为 [venera-app/venera](https://github.com/venera-app/venera)。

`main` 分支主要用于分发自用的测试构建：日常修改会直接进入 `main`，并以 Release 的形式发布安装包。构建可能包含未完成功能、激进改动或数据格式变化，**不保证稳定**；如果你需要稳定版本，请使用上游 [haukuen/venera](https://github.com/haukuen/venera)或其他版本[^all-repo]。

[^all-repo]: 目前社区后起之秀有：[VeneraX](https://github.com/Kyosee/VeneraX)、[Venera-Next](https://github.com/CyrilPeng/Venera-Next)、[venera-prime](https://github.com/venera-app/venera-prime) 等，因不喜欢其代码提交方式而未使用

## 与上游的区别

1. **Anime4K 超分**: 阅读器内置纯 Dart 的 Anime4K 超分，可随时在原图和超分图之间切换。支持本地与网络图片，可调放大倍率、线条细化强度和边缘精炼强度；结果带本地缓存，并按缓存上限自动清理。
2. **Bangumi 同步**: 可将书架漫画关联到 Bangumi 条目，同步收藏状态与阅读进度。支持条目搜索、关联管理、批量解除关联、进度同步提醒和缩略图状态徽标。默认关闭，需要在设置中开启并配置 Access Token。
3. **冷启动自动导出**: 开启后每次冷启动都会导出一份完整应用数据，包含登录 Cookie 和 Bangumi Token，保留最新 10 份。桌面与 iOS 位于 `Venera/Backups`，Android 位于应用私有 Documents 目录，卸载应用时会一并删除。

以上功能全部默认关闭，需要主动开启；其余功能、界面和数据模型基本沿用上游。

## 迁移

为了上游版本共存，应用包名已改为 `cc.bgzo.venera`，因此本地数据**不会**自动继承，需要重新迁移数据。

> [!WARNING]
> **WebDAV 同步目录不要和上游共用**。默认目录仍是 `/venera_backup/`，请改成独立目录（例如 `/venera_bgzo_backup/`），否则两边可能互相覆盖数据。

## 使用场景与测试平台

主要验证平台是 **iPad OS + Mac OS**。其他平台的构建会跟随 Flutter 工程产出，但不作为主力使用场景，未充分测试。

> [!NOTE]
> 自签建议使用万能签，因近期 Apple 严打，已经非常不稳定，不再建议使用 SideStore/AltStore + Live Container

## 致谢

- [venera-app/venera](https://github.com/venera-app/venera)：原项目与漫画源生态。
- [haukuen/venera](https://github.com/haukuen/venera)：本分支的直接上游。
- [venera-app/venera-configs](https://github.com/venera-app/venera-configs)：漫画源配置与脚本 API。
- [Anime4K](https://github.com/bloc97/Anime4K)：超分算法。
- [Bangumi](https://bgm.tv/)：条目、收藏与进度 API。

## 免责声明

本项目仅用于个人学习、测试和自用分发，与上游项目及其作者无隶属或官方关联。应用本身不提供、存储或分发任何漫画内容，所有内容均来自用户自行配置的第三方漫画源，相关版权归原作者及权利人所有。请遵守当地法律法规和内容平台的使用条款，因使用本分支产生的任何后果由使用者自行承担。软件按“现状”提供，不提供任何明示或暗示的担保。
