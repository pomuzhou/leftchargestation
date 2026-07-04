# ⚡ 天大充电地图 (TJU Charging Map)

> **实时空余充电桩查询 · 拟真拟物暗黑美学 · 校园生活效率助手**

这是一个为天津大学（天津大学卫津路校区 & 北洋园校区）师生量身定制的**第三方智能充电桩地图导航助手**。通过高颜值的可视化暗黑风地图界面，实时展现学校各个宿舍楼区、教学楼、车棚的空闲充电枪口数量，告别“推车寻找空桩”的焦虑。

*注：本项目默认以**纯前端离线模拟数据**运行，提供极致的渲染速度与拟真状态动画，同时为开发者预留了安全的数据同步扩展接口。*

---

## 🌟 核心亮点

* 🎨 **高端暗黑拟物美学**：精心定制的 Glassmorphism（毛玻璃玻璃拟物）卡片与暗金渐变色彩系统，专为夜间寻找充电桩的移动端场景优化，夜间使用不刺眼。
* 🗺️ **实时动态地图**：基于高德/CartoDB 暗色系地图底图，支持卫津路与北洋园双校区一键无缝定位，大头针颜色随空闲枪数（充足-黄色紧张-红色已满）实时改变。
* 🚀 **地图点位拖拽微调**：内置“上帝模式”，开启拖拽模式后，用户可以直接在地图上长按并拖动图标，将电桩精准放置在教学楼或宿舍窗前。新坐标**自动持久化存储于本地浏览器**，刷新不丢失。
* 💾 **一键导入导出备份**：由于不同域名（如局域网IP与公网域名）间本地存储隔离，项目支持一键导出/导入坐标文本，轻松在不同设备间迁移您的完美微调地图。
* 📱 **极致移动端响应式**：针对 iPhone/Android 浏览器进行深度排版适配，底部上滑抽屉菜单（Drawer）手势顺滑，且支持断网离线 PWA 式快速打开。

---

## 🛠️ 快速上手与部署

本项目为**单 HTML 页面架构**，无需复杂的 Node.js 构建环境，开箱即用。

### 1. 本地双击打开
直接双击 `index.html`，即可在电脑或手机浏览器中打开，默认会启动**“动态模拟数据”**（每 8 秒随机增减空闲桩，模拟真实场景）。

### 2. 免费云端部署
如果您想将网页分享给其他同学：
1. **GitHub Pages**：直接将代码上传至 GitHub，在仓库的 `Settings -> Pages` 中开启 GitHub Pages，即可获得免费的公网网址。
2. **Vercel / Cloudflare Pages**：直接导入此 GitHub 仓库，即可一键上线（自动获得全球 CDN 加速，国内访问“秒开”）。

---

## 🔌 开发者进阶：接入学校真实数据

本网页内置了天大卫津路全部 9 个宿舍及车棚的接口匹配逻辑。如果您是技术开发者，希望在您的手机上看到真实的实时数据，可以进行以下配置：

### 第一步：微信抓包获取 Token
1. 在手机上打开天大充电桩的官方微信小程序（如常青藤智能充电）。
2. 使用抓包工具（如 Charles、Fiddler 或手机端的 HTTP Catcher）抓取任意一个查询电桩列表的请求。
3. 提取 Request Headers（请求头）中的 **`Authorization`** 或 **`token`** 字段值（格式通常为 `Bearer eyJhbGci...`）。

### 第二步：配置/部署中转代理服务（解决跨域限制）
因为微信接口限制了必须国内网络且有 CORS 浏览器跨域封锁，您可以通过以下两种方式建立跨域代理服务：

#### 方案 A：部署免登录云函数（推荐，实现 24 小时免开机）
您可以在国内免费云开发平台（如 **Sealos / Laf**）上创建一个名为 `proxy` 的云函数，代码如下：

```javascript
import https from 'https'
import { URL } from 'url'

export default async function (ctx) {
  const res = ctx.res
  const query = ctx.query || {}
  const headers = ctx.req?.headers || ctx.headers || {}
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, token'
  }
  if (res) res.set(corsHeaders)
  if (ctx.req?.method === 'OPTIONS') return res.status(204).send()

  try {
    const decodedUrl = decodeURIComponent(query.url)
    const parsedUrl = new URL(decodedUrl)
    const reqHeaders = {}
    if (headers['authorization']) reqHeaders['Authorization'] = headers['authorization']
    if (headers['token']) reqHeaders['token'] = headers['token']

    const responseBody = await new Promise((resolve, reject) => {
      https.get({
        hostname: parsedUrl.hostname,
        path: parsedUrl.pathname + parsedUrl.search,
        headers: reqHeaders,
        rejectUnauthorized: false
      }, (response) => {
        let data = ''
        response.on('data', (chunk) => { data += chunk })
        response.on('end', () => resolve(data))
      }).on('error', reject)
    })
    return res.status(200).send(JSON.parse(responseBody))
  } catch (e) {
    return res.status(500).send({ error: e.message })
  }
}
```

#### 方案 B：本地运行 PowerShell 代理（适合局域网测试/不想注册云平台）
如果您不想注册任何云服务，且手机与运行代码的电脑处于同一个局域网（如天津大学校园网/同一个 Wi-Fi 下），可以直接运行项目内置的 **`server.ps1`** 脚本：

1. **启动服务**：
   * 在电脑项目目录下打开 PowerShell 终端。
   * 运行以下命令，启动本地中转代理监听服务（默认监听本地 `8000` 端口）：
     ```powershell
     powershell -ExecutionPolicy Bypass -File server.ps1
     ```
2. **手机端接入**：
   * 获取您电脑在局域网中的 IP 地址（例如 `172.26.153.243`）。
   * 在手机端网页配置中，将自定义代理服务器地址填为：
     `http://<您的电脑局域网IP>:8000`
3. **公网穿透（可选）**：
   * 若想离开校园网依然能通过电脑代理访问，可以使用 Windows 自带 SSH 发起公网穿透（如 `ssh -p 443 -R0:localhost:8000 a.pinggy.link`），并将生成的公网 HTTPS 地址填入手机端。


### 第三步：在网页设置中填入配置
打开网页，点击右上角⚙️图标：
1. 切换到 **“开发者数据对接”** 面板；
2. 填入您**云函数的公网连接地址**；
3. 填入您抓包获取的 **Token**；
4. 点击 **「更新配置并同步」**。此时网页将立即通过您的云函数，以安全的速度限速拉取天大各点位的实时真实数据！

---

## 💖 支持与赞助 (Buy Me a Coffee)

这是一个完全由天津大学学生利用业余时间开发和维护的**公益性开源学习项目**。

虽然本项目前端托管在免费平台上，但为了支持未来更多实用功能（如：**某斋充电桩空出时，自动发送手机短信/邮件提醒**等高级云端服务），以及维持高防代理云函数的日常微量带宽开销，如果您觉得这个地图切实帮您节省了寻找电桩的时间，欢迎赞助一杯咖啡支持作者！

您的每一份支持，都将成为这个项目继续更新下去的动力！

| 微信扫码赞助 | 支付宝扫码赞助 |
| :---: | :---: |
| <img src="docs/wechat_pay.jpg" width="220" alt="微信赞助二维码" /> | <img src="docs/alipay.jpg" width="220" alt="支付宝赞助二维码" /> |

*(打赏时欢迎备注您的 TJU 斋号/昵称，我们会将所有赞助人名单登记于下方的致谢栏中！)*

### 🎁 特别致谢列表 (Backers)
* 暂无（期待您的加入！）

---

## ⚖️ 免责声明

1. 本项目仅作为个人对前端 GIS 可视化、Leaflet 框架及前端缓存技术的学习交流使用。
2. 代码默认提供的所有接口、Token 和配置信息均为**虚构的本地模拟演示数据**，不代表真实的校园用电设备状态。
3. 用户因自行进行抓包、测试接口等行为引发的一切网络安全责任或账号风控纠纷，均由使用者本人承担，与本项目作者及开源平台无关。
4. 如有侵权，请联系作者删除对应内容。
