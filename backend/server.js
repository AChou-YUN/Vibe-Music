const { serveNcmApi } = require('NeteaseCloudMusicApi')

const PORT = process.env.PORT || 3000
const HOST = process.env.HOST || '127.0.0.1'

serveNcmApi({
  port: PORT,
  host: HOST,
  checkVersion: false,
}).then((server) => {
  console.log(`[NeteaseCloudMusicApi] running @ http://${HOST}:${PORT}`)
}).catch((err) => {
  console.error('[NeteaseCloudMusicApi] Failed to start:', err)
  process.exit(1)
})
