const pet = document.getElementById('pet')
const bubble = document.getElementById('bubble')
const bubbleText = document.getElementById('bubble-text')
const figure = document.getElementById('pet-figure')
const linesElement = document.getElementById('catgirl-lines')

const fallbackLines = ['喵～', '要好好写代码哦喵～', '摸摸猫耳朵喵～']
let lines = fallbackLines

try {
  const parsed = JSON.parse(linesElement?.textContent ?? '[]')
  if (Array.isArray(parsed) && parsed.length > 0) {
    lines = parsed.filter(line => typeof line === 'string' && line.trim().length > 0)
  }
} catch {
  lines = fallbackLines
}

if (lines.length === 0) lines = fallbackLines

const scale = Number(document.body.dataset.scale)
if (Number.isFinite(scale) && scale > 0) {
  figure.style.setProperty('--pet-scale', String(scale))
}

let lastIndex = -1

function speak() {
  let index = Math.floor(Math.random() * lines.length)
  if (lines.length > 1 && index === lastIndex) {
    index = (index + 1) % lines.length
  }
  lastIndex = index
  bubbleText.textContent = lines[index]
  bubble.hidden = false
  bubble.style.animation = 'none'
  void bubble.offsetWidth
  bubble.style.animation = ''
  pet.classList.remove('happy')
  void pet.offsetWidth
  pet.classList.add('happy')
}

pet.addEventListener('click', speak)
pet.addEventListener('animationend', () => pet.classList.remove('happy'))

const interval = Number(document.body.dataset.interval)
if (Number.isFinite(interval) && interval >= 2000) {
  setInterval(speak, interval)
}

figure.addEventListener('dblclick', () => {
  bubbleText.textContent = '诶嘿，被摸头了喵～'
  bubble.hidden = false
})
