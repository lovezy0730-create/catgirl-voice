// 把模型生成的「角色变体图」压成只覆盖变化区域的叠图，供桌宠做眨眼与耳朵抖动。
//
// 用法（需要 Node 18+ 与 sharp）：
//   node prepare-character-art.mjs <角色目录> [输出宽度] [密度阈值] [膨胀半径] [羽化sigma]
// 例：
//   node prepare-character-art.mjs ../character/elaina_catgirl 640 0.45 4 5
//
// 输入约定（放在角色目录里）：
//   base.source.png        主立绘原图（必需，若只有 base.png 会先复制成 .source）
//   eyes_half.source.png   半睁眼变体（可选，需与 eyes_closed 成对）
//   eyes_closed.source.png 闭眼变体（可选）
//   ears.source.png        只改耳朵的变体（可选）
//
// 输出：
//   base.png / eyes_half.png / eyes_closed.png / ears.png
//
// 处理思路：与主图求差异 → 取局部密度高的区域 → 限制在脸部/耳朵横带 → 与主图不透明区求交并往内收
// （避免眨眼时把叠图自己的背景糊到透明背景上）→ 膨胀 + 羽化。

import sharp from 'sharp'
import { copyFileSync, existsSync, statSync } from 'node:fs'

const directory = process.argv[2]
if (!directory) {
  console.error('缺少角色目录参数')
  process.exit(1)
}

const outputWidth = Number(process.argv[3] ?? 640)
const densityThreshold = Number(process.argv[4] ?? 0.45)
const dilateRadius = Number(process.argv[5] ?? 4)
const featherSigma = Number(process.argv[6] ?? 5)

const FACE_BAND = { x0: 0.18, y0: 0.24, x1: 0.70, y1: 0.50 }
const EAR_BAND = { x0: 0.00, y0: 0.00, x1: 1.00, y1: 0.42 }
const DENSITY_RADIUS = 6
const DIFF_THRESHOLD = 24
const OPAQUE_ALPHA = 200
const ERODE_RADIUS = 2

async function raw(path) {
  return sharp(path).ensureAlpha().raw().toBuffer({ resolveWithObject: true })
}

const stems = ['eyes_half', 'eyes_closed']
for (const stem of stems) {
  const backupPath = `${directory}\\${stem}.source.png`
  if (!existsSync(backupPath) && existsSync(`${directory}\\${stem}.png`)) {
    copyFileSync(`${directory}\\${stem}.png`, backupPath)
  }
}
if (!existsSync(`${directory}\\base.source.png`)) copyFileSync(`${directory}\\base.png`, `${directory}\\base.source.png`)

const base = await raw(`${directory}\\base.source.png`)
const width = base.info.width
const height = base.info.height

function toBand(band) {
  return {
    x0: Math.round(width * band.x0),
    y0: Math.round(height * band.y0),
    x1: Math.round(width * band.x1),
    y1: Math.round(height * band.y1),
  }
}

function diffMask(other) {
  const mask = new Uint8Array(width * height)
  for (let i = 0; i < width * height; i += 1) {
    const p = i * 4
    const delta = Math.max(
      Math.abs(base.data[p] - other.data[p]),
      Math.abs(base.data[p + 1] - other.data[p + 1]),
      Math.abs(base.data[p + 2] - other.data[p + 2]),
      Math.abs(base.data[p + 3] - other.data[p + 3])
    )
    mask[i] = delta > DIFF_THRESHOLD ? 1 : 0
  }
  return mask
}

function integral(mask) {
  const sums = new Int32Array((width + 1) * (height + 1))
  for (let y = 0; y < height; y += 1) {
    let rowSum = 0
    for (let x = 0; x < width; x += 1) {
      rowSum += mask[y * width + x]
      sums[(y + 1) * (width + 1) + (x + 1)] = sums[y * (width + 1) + (x + 1)] + rowSum
    }
  }
  return sums
}

function boxSum(sums, x0, y0, x1, y1) {
  return sums[y1 * (width + 1) + x1] - sums[y0 * (width + 1) + x1] - sums[y1 * (width + 1) + x0] + sums[y0 * (width + 1) + x0]
}

function denseMask(mask, band) {
  const area = toBand(band)
  const sums = integral(mask)
  const dense = new Uint8Array(width * height)
  for (let y = area.y0; y < area.y1; y += 1) {
    for (let x = area.x0; x < area.x1; x += 1) {
      const x0 = Math.max(0, x - DENSITY_RADIUS)
      const y0 = Math.max(0, y - DENSITY_RADIUS)
      const x1 = Math.min(width, x + DENSITY_RADIUS + 1)
      const y1 = Math.min(height, y + DENSITY_RADIUS + 1)
      const density = boxSum(sums, x0, y0, x1, y1) / ((x1 - x0) * (y1 - y0))
      if (density >= densityThreshold) dense[y * width + x] = 1
    }
  }
  return dense
}

function dilate(mask) {
  const sums = integral(mask)
  const grown = new Uint8Array(width * height)
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const x0 = Math.max(0, x - dilateRadius)
      const y0 = Math.max(0, y - dilateRadius)
      const x1 = Math.min(width, x + dilateRadius + 1)
      const y1 = Math.min(height, y + dilateRadius + 1)
      if (boxSum(sums, x0, y0, x1, y1) > 0) grown[y * width + x] = 255
    }
  }
  return grown
}

function baseOpaqueMask() {
  const opaque = new Uint8Array(width * height)
  const transparent = new Uint8Array(width * height)
  for (let i = 0; i < width * height; i += 1) {
    const solid = base.data[i * 4 + 3] >= OPAQUE_ALPHA
    opaque[i] = solid ? 1 : 0
    transparent[i] = solid ? 0 : 1
  }
  const sums = integral(transparent)
  const eroded = new Uint8Array(width * height)
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const i = y * width + x
      if (!opaque[i]) continue
      const x0 = Math.max(0, x - ERODE_RADIUS)
      const y0 = Math.max(0, y - ERODE_RADIUS)
      const x1 = Math.min(width, x + ERODE_RADIUS + 1)
      const y1 = Math.min(height, y + ERODE_RADIUS + 1)
      if (boxSum(sums, x0, y0, x1, y1) === 0) eroded[i] = 1
    }
  }
  return eroded
}

const opaque = baseOpaqueMask()
const opaqueAlpha = new Uint8Array(width * height)
for (let i = 0; i < width * height; i += 1) {
  opaqueAlpha[i] = opaque[i] ? 255 : 0
}

function maskBuffer(alpha) {
  const rgba = Buffer.alloc(width * height * 4)
  for (let i = 0; i < width * height; i += 1) {
    const p = i * 4
    rgba[p] = 255
    rgba[p + 1] = 255
    rgba[p + 2] = 255
    rgba[p + 3] = alpha[i]
  }
  return rgba
}

async function gatedMaskTexture(binaryMask) {
  const blurred = await sharp(maskBuffer(dilate(binaryMask)), { raw: { width, height, channels: 4 } })
    .blur(featherSigma)
    .png()
    .toBuffer()
  const opacityMask = await sharp(maskBuffer(opaqueAlpha), { raw: { width, height, channels: 4 } }).png().toBuffer()
  return sharp(blurred)
    .ensureAlpha()
    .composite([{ input: opacityMask, blend: 'dest-in' }])
    .png()
    .toBuffer()
}

async function writePatch(stem, binaryMask) {
  const output = `${directory}\\${stem}.png`
  const composited = await sharp(`${directory}\\${stem}.source.png`)
    .ensureAlpha()
    .composite([{ input: await gatedMaskTexture(binaryMask), blend: 'dest-in' }])
    .png({ compressionLevel: 9 })
    .toBuffer()
  await sharp(composited).resize({ width: outputWidth }).png({ compressionLevel: 9 }).toFile(output)
  const covered = binaryMask.reduce((total, value) => total + value, 0)
  console.log(`${stem}.png ← 遮罩约 ${covered} 像素，输出 ${(statSync(output).size / 1024).toFixed(0)} KB`)
}

console.log(`画布 ${width}x${height}，输出宽度 ${outputWidth}`)

const eyeDense = new Map()
for (const stem of stems) {
  eyeDense.set(stem, denseMask(diffMask(await raw(`${directory}\\${stem}.source.png`)), FACE_BAND))
}
const eyeShared = new Uint8Array(width * height)
for (let i = 0; i < width * height; i += 1) {
  eyeShared[i] = eyeDense.get('eyes_half')[i] && eyeDense.get('eyes_closed')[i] && opaque[i] ? 1 : 0
}
console.log(`眼睛遮罩覆盖 ${(eyeShared.reduce((total, value) => total + value, 0) / (width * height) * 100).toFixed(2)}%`)
for (const stem of stems) {
  await writePatch(stem, eyeShared)
}

if (existsSync(`${directory}\\ears.source.png`)) {
  const earDense = denseMask(diffMask(await raw(`${directory}\\ears.source.png`)), EAR_BAND)
  const earMask = new Uint8Array(width * height)
  for (let i = 0; i < width * height; i += 1) {
    earMask[i] = earDense[i] && opaque[i] ? 1 : 0
  }
  console.log(`耳朵遮罩覆盖 ${(earMask.reduce((total, value) => total + value, 0) / (width * height) * 100).toFixed(2)}%`)
  await writePatch('ears', earMask)
} else {
  console.log('没有 ears.source.png，跳过耳朵叠图')
}

await sharp(`${directory}\\base.source.png`).resize({ width: outputWidth }).png({ compressionLevel: 9 }).toFile(`${directory}\\base.png`)
console.log(`base.png ← 缩放到 ${outputWidth}px`)
