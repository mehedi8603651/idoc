import React, { useEffect, useMemo, useRef, useState } from 'react'
import { EditorContent, NodeViewWrapper, ReactNodeViewRenderer, useEditor } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Paragraph from '@tiptap/extension-paragraph'
import Heading from '@tiptap/extension-heading'
import Blockquote from '@tiptap/extension-blockquote'
import BulletList from '@tiptap/extension-bullet-list'
import OrderedList from '@tiptap/extension-ordered-list'
import ListItem from '@tiptap/extension-list-item'
import HorizontalRule from '@tiptap/extension-horizontal-rule'
import { Node, mergeAttributes } from '@tiptap/core'
import { NodeSelection, TextSelection } from '@tiptap/pm/state'

function hasFlutterBridge() {
  return Boolean(window.chrome?.webview)
}

function waitForFlutterBridge(callback, attempts = 120) {
  if (hasFlutterBridge()) {
    callback()
    return () => {}
  }

  let remaining = attempts
  const timer = window.setInterval(() => {
    if (hasFlutterBridge()) {
      window.clearInterval(timer)
      callback()
      return
    }
    remaining -= 1
    if (remaining <= 0) {
      window.clearInterval(timer)
    }
  }, 50)

  return () => window.clearInterval(timer)
}

const blankDoc = {
  type: 'doc',
  content: [
    {
      type: 'paragraph',
      attrs: {
        elementId: createElementId(),
        elementType: 'paragraph',
        fontSize: null,
      },
    },
  ],
}

const slashItems = [
  { value: 'paragraph', label: 'Paragraph' },
  { value: 'heading-1', label: 'Heading 1' },
  { value: 'heading-2', label: 'Heading 2' },
  { value: 'heading-3', label: 'Heading 3' },
  { value: 'quote', label: 'Quote' },
  { value: 'list-bulleted', label: 'Bulleted list' },
  { value: 'list-numbered', label: 'Numbered list' },
  { value: 'callout', label: 'Callout' },
  { value: 'button', label: 'Button' },
  { value: 'link', label: 'Link' },
  { value: 'code', label: 'Code' },
  { value: 'image', label: 'Image' },
  { value: 'question', label: 'Question' },
  { value: 'input', label: 'Input' },
  { value: 'spacer', label: 'Spacer' },
  { value: 'pagebreak', label: 'Page break' },
]

const ParagraphNode = Paragraph.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      elementId: {
        default: null,
        parseHTML: element => element.getAttribute('data-element-id'),
        renderHTML: attributes =>
          attributes.elementId ? { 'data-element-id': attributes.elementId } : {},
      },
      elementType: {
        default: 'paragraph',
        parseHTML: element => element.getAttribute('data-element-type') || 'paragraph',
        renderHTML: attributes =>
          attributes.elementType ? { 'data-element-type': attributes.elementType } : {},
      },
      fontSize: {
        default: null,
        parseHTML: element => {
          const raw = element.getAttribute('data-font-size')
          return raw ? Number(raw) : null
        },
        renderHTML: attributes =>
          attributes.fontSize
            ? {
                'data-font-size': attributes.fontSize,
                style: `font-size:${attributes.fontSize}px;`,
              }
            : {},
      },
    }
  },
})

const HeadingNode = Heading.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      elementId: {
        default: null,
        parseHTML: element => element.getAttribute('data-element-id'),
        renderHTML: attributes =>
          attributes.elementId ? { 'data-element-id': attributes.elementId } : {},
      },
      fontSize: {
        default: null,
        parseHTML: element => {
          const raw = element.getAttribute('data-font-size')
          return raw ? Number(raw) : null
        },
        renderHTML: attributes =>
          attributes.fontSize
            ? {
                'data-font-size': attributes.fontSize,
                style: `font-size:${attributes.fontSize}px;`,
              }
            : {},
      },
    }
  },
})

const BlockquoteNode = Blockquote.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      elementId: {
        default: null,
        parseHTML: element => element.getAttribute('data-element-id'),
        renderHTML: attributes =>
          attributes.elementId ? { 'data-element-id': attributes.elementId } : {},
      },
      fontSize: {
        default: null,
        parseHTML: element => {
          const raw = element.getAttribute('data-font-size')
          return raw ? Number(raw) : null
        },
        renderHTML: attributes =>
          attributes.fontSize
            ? {
                'data-font-size': attributes.fontSize,
                style: `font-size:${attributes.fontSize}px;`,
              }
            : {},
      },
    }
  },
})

const BulletListNode = BulletList.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      elementId: {
        default: null,
        parseHTML: element => element.getAttribute('data-element-id'),
        renderHTML: attributes =>
          attributes.elementId ? { 'data-element-id': attributes.elementId } : {},
      },
      fontSize: {
        default: null,
        parseHTML: element => {
          const raw = element.getAttribute('data-font-size')
          return raw ? Number(raw) : null
        },
        renderHTML: attributes =>
          attributes.fontSize
            ? {
                'data-font-size': attributes.fontSize,
                style: `font-size:${attributes.fontSize}px;`,
              }
            : {},
      },
    }
  },
})

const OrderedListNode = OrderedList.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      elementId: {
        default: null,
        parseHTML: element => element.getAttribute('data-element-id'),
        renderHTML: attributes =>
          attributes.elementId ? { 'data-element-id': attributes.elementId } : {},
      },
      fontSize: {
        default: null,
        parseHTML: element => {
          const raw = element.getAttribute('data-font-size')
          return raw ? Number(raw) : null
        },
        renderHTML: attributes =>
          attributes.fontSize
            ? {
                'data-font-size': attributes.fontSize,
                style: `font-size:${attributes.fontSize}px;`,
              }
            : {},
      },
    }
  },
})

const HorizontalRuleNode = HorizontalRule.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      elementId: {
        default: null,
        parseHTML: element => element.getAttribute('data-element-id'),
        renderHTML: attributes =>
          attributes.elementId ? { 'data-element-id': attributes.elementId } : {},
      },
    }
  },
})

const IdocBlockView = ({ node, selected, updateAttributes }) => {
  const attrs = node.attrs ?? {}
  const isImageBlock = attrs.elementType === 'image'
  const preview = attrs.preview || ''
  const imageSrc = attrs.imageSrc || ''
  const imageAlt = attrs.imageAlt || 'Image'
  const widthFactor = normalizedBlockWidth(attrs.width)
  const width = `${Math.round(widthFactor * 100)}%`
  const imageFrameRef = useRef(null)
  const imageRef = useRef(null)
  const dragStateRef = useRef(null)

  useEffect(() => {
    return () => {
      const state = dragStateRef.current
      if (!state) {
        return
      }
      window.removeEventListener('pointermove', state.onMove)
      window.removeEventListener('pointerup', state.onUp)
      dragStateRef.current = null
    }
  }, [])

  const beginResize = direction => event => {
    if (attrs.elementType !== 'image') {
      return
    }
    event.preventDefault()
    event.stopPropagation()

    const frameRect = imageFrameRef.current?.getBoundingClientRect()
    const parentRect = imageFrameRef.current?.closest('.tiptap')?.getBoundingClientRect()
    const startWidthPx = frameRect?.width ?? 320
    const editorWidthPx = Math.max(parentRect?.width ?? startWidthPx, 240)
    const naturalWidth = imageRef.current?.naturalWidth ?? 0
    const naturalHeight = imageRef.current?.naturalHeight ?? 0
    const aspectRatio = naturalWidth > 0 && naturalHeight > 0
      ? naturalWidth / naturalHeight
      : 1.6

    const handleMove = moveEvent => {
      const horizontalDelta = (moveEvent.clientX - event.clientX) * direction
      const verticalDelta = (moveEvent.clientY - event.clientY) * direction * aspectRatio
      const delta = Math.abs(horizontalDelta) >= Math.abs(verticalDelta)
        ? horizontalDelta
        : verticalDelta
      const nextWidthPx = clamp(startWidthPx + delta, 180, editorWidthPx)
      updateAttributes({
        width: Number((nextWidthPx / editorWidthPx).toFixed(4)),
      })
    }

    const handleUp = () => {
      window.removeEventListener('pointermove', handleMove)
      window.removeEventListener('pointerup', handleUp)
      dragStateRef.current = null
    }

    dragStateRef.current = { onMove: handleMove, onUp: handleUp }
    window.addEventListener('pointermove', handleMove)
    window.addEventListener('pointerup', handleUp)
  }

  return (
    <NodeViewWrapper
      className={`idoc-block-card${selected ? ' is-selected' : ''}${isImageBlock ? ' is-image-block' : ''}`}
      style={{ width }}
      data-element-id={attrs.elementId || ''}
      data-element-type={attrs.elementType || ''}
      contentEditable={false}
    >
      {!isImageBlock ? (
        <div className="idoc-block-badge">{labelize(attrs.elementType || 'block')}</div>
      ) : null}
      {isImageBlock && imageSrc ? (
        <div className="idoc-block-image-frame-wrap">
          <div
            ref={imageFrameRef}
            className="idoc-block-image-frame"
          >
            <img
              ref={imageRef}
              className="idoc-block-image"
              src={imageSrc}
              alt={imageAlt}
              draggable={false}
            />
          </div>
          {selected ? (
            <>
              <button
                type="button"
                className="idoc-image-resize-handle is-top-left"
                aria-label="Resize image proportionally from top left"
                onPointerDown={beginResize(-1)}
              />
              <button
                type="button"
                className="idoc-image-resize-handle is-top-right"
                aria-label="Resize image proportionally from top right"
                onPointerDown={beginResize(1)}
              />
              <button
                type="button"
                className="idoc-image-resize-handle is-bottom-right"
                aria-label="Resize image proportionally from bottom right"
                onPointerDown={beginResize(1)}
              />
              <button
                type="button"
                className="idoc-image-resize-handle is-bottom-left"
                aria-label="Resize image proportionally from bottom left"
                onPointerDown={beginResize(-1)}
              />
            </>
          ) : null}
        </div>
      ) : null}
      {preview && !isImageBlock ? <div className="idoc-block-preview">{preview}</div> : null}
    </NodeViewWrapper>
  )
}

const IdocBlockNode = Node.create({
  name: 'idocBlock',
  group: 'block',
  atom: true,
  selectable: true,
  draggable: true,
  addAttributes() {
    return {
      elementId: {
        default: null,
      },
      elementType: {
        default: 'block',
      },
      width: {
        default: 1,
      },
      preview: {
        default: '',
      },
      imageSrc: {
        default: '',
      },
      imageAlt: {
        default: '',
      },
    }
  },
  parseHTML() {
    return [{ tag: 'idoc-block' }]
  },
  renderHTML({ HTMLAttributes }) {
    return [
      'idoc-block',
      mergeAttributes(HTMLAttributes, {
        'data-element-id': HTMLAttributes.elementId,
        'data-element-type': HTMLAttributes.elementType,
      }),
    ]
  },
  addNodeView() {
    return ReactNodeViewRenderer(IdocBlockView)
  },
})

function createElementId() {
  const random = Math.random().toString(36).slice(2, 8)
  return `block-web-${Date.now().toString(36)}-${random}`
}

function labelize(value) {
  if (!value) {
    return 'Block'
  }
  const normalized = value.replace(/[_-]+/g, ' ')
  return normalized.charAt(0).toUpperCase() + normalized.slice(1)
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value))
}

function normalizedBlockWidth(value) {
  return typeof value === 'number' ? clamp(value, 0.2, 1) : 1
}

function readFlutterMessage(event) {
  try {
    return typeof event.data === 'string' ? JSON.parse(event.data) : event.data
  } catch (error) {
    console.warn('Invalid Flutter message', error)
    return null
  }
}

function findTopLevelNodeSelection(editor) {
  const selection = editor.state.selection
  if (!selection) {
    return null
  }
  const depth = selection.$from.depth >= 1 ? 1 : 0
  const node = selection.$from.node(depth)
  const pos = depth > 0 ? selection.$from.before(depth) : 0
  return { node, pos, depth }
}

function currentTextStyle(editor) {
  if (editor.isActive('heading', { level: 1 })) return 'heading-1'
  if (editor.isActive('heading', { level: 2 })) return 'heading-2'
  if (editor.isActive('heading', { level: 3 })) return 'heading-3'
  if (editor.isActive('blockquote')) return 'quote'
  if (editor.isActive('bulletList')) return 'list-bulleted'
  if (editor.isActive('orderedList')) return 'list-numbered'
  return 'paragraph'
}

function isSlashTriggerActive(editor) {
  const info = findTopLevelNodeSelection(editor)
  if (!info || info.node.type.name !== 'paragraph' || !editor.state.selection.empty) {
    return false
  }
  return info.node.textContent.trim() === '/'
}

function clearSlashTrigger(editor) {
  const info = findTopLevelNodeSelection(editor)
  if (!info) {
    return
  }
  const from = info.pos + 1
  const to = info.pos + info.node.nodeSize - 1
  editor.chain().focus().deleteRange({ from, to }).run()
}

function applyStyle(editor, style) {
  ensureSelection(editor)
  const chain = editor.chain().focus()
  switch (style) {
    case 'heading-1':
      chain.setHeading({ level: 1 }).run()
      return
    case 'heading-2':
      chain.setHeading({ level: 2 }).run()
      return
    case 'heading-3':
      chain.setHeading({ level: 3 }).run()
      return
    case 'quote':
      chain.toggleBlockquote().run()
      return
    case 'list-bulleted':
      chain.toggleBulletList().run()
      return
    case 'list-numbered':
      chain.toggleOrderedList().run()
      return
    default:
      chain.setParagraph().run()
      return
  }
}

function isFontSizeNode(node) {
  const type = node?.type?.name
  return (
    type === 'paragraph' ||
    type === 'heading' ||
    type === 'blockquote' ||
    type === 'bulletList' ||
    type === 'orderedList'
  )
}

function ensureSelection(editor) {
  if (!editor) {
    return false
  }
  const selection = editor.state.selection
  if (selection) {
    return true
  }
  editor.commands.focus('end')
  return true
}

function clipboardImageFile(event) {
  const items = Array.from(event?.clipboardData?.items ?? [])
  for (const item of items) {
    if (typeof item.type === 'string' && item.type.startsWith('image/')) {
      return item.getAsFile()
    }
  }
  return null
}

function imageFileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(typeof reader.result === 'string' ? reader.result : '')
    reader.onerror = () => reject(reader.error ?? new Error('Could not read pasted image.'))
    reader.readAsDataURL(file)
  })
}

function clipboardImageAlt(file) {
  const rawName = typeof file?.name === 'string' ? file.name.trim() : ''
  if (!rawName) {
    return 'Pasted image'
  }
  const withoutExtension = rawName.replace(/\.[^.]+$/, '').trim()
  return withoutExtension || 'Pasted image'
}

async function postClipboardImageToFlutter(file) {
  try {
    const imageDataUrl = await imageFileToDataUrl(file)
    if (!imageDataUrl.startsWith('data:image/')) {
      return false
    }
    postToFlutter({
      type: 'requestInsertBlock',
      payload: {
        elementType: 'image',
        imageDataUrl,
        alt: clipboardImageAlt(file),
      },
    })
    return true
  } catch (error) {
    console.warn('Could not import pasted image', error)
    return false
  }
}

function topLevelNodesInSelection(editor, predicate) {
  const selection = editor.state.selection
  if (!selection) {
    return []
  }

  const { from, to, empty } = selection
  const result = []

  editor.state.doc.forEach((node, offset) => {
    if (!predicate(node)) {
      return
    }
    const start = offset
    const end = offset + node.nodeSize
    const overlaps = empty
      ? from >= start && from <= end
      : from < end && to > start
    if (overlaps) {
      result.push({ node, pos: offset })
    }
  })

  return result
}

function applyFontSize(editor, fontSize) {
  ensureSelection(editor)
  const targets = topLevelNodesInSelection(editor, isFontSizeNode)
  if (!targets.length) {
    return false
  }

  const transaction = editor.state.tr
  targets.forEach(({ node, pos }) => {
    const attrs = { ...(node.attrs ?? {}) }
    attrs.fontSize = typeof fontSize === 'number' ? fontSize : null
    transaction.setNodeMarkup(pos, undefined, attrs, node.marks)
  })
  editor.view.dispatch(transaction)
  postSelection(editor)
  return true
}

function findElementNodePosition(editor, elementId) {
  let found = null
  editor.state.doc.descendants((node, pos) => {
    if (node.attrs?.elementId === elementId) {
      const depth = editor.state.doc.resolve(pos).depth
      if (depth <= 1) {
        found = { node, pos }
        return false
      }
    }
    return true
  })
  return found
}

function normalizeTopLevelIds(editor) {
  const used = new Set()
  let changed = false
  const transaction = editor.state.tr

  editor.state.doc.forEach((node, offset) => {
    if (node.type.name === 'doc') {
      return
    }
    const attrs = { ...(node.attrs ?? {}) }
    let nextId = typeof attrs.elementId === 'string' ? attrs.elementId : ''
    if (!nextId || used.has(nextId)) {
      nextId = createElementId()
      attrs.elementId = nextId
      changed = true
    }
    used.add(nextId)

    if (!attrs.elementType && node.type.name === 'paragraph') {
      attrs.elementType = 'paragraph'
      changed = true
    }

    if (changed) {
      transaction.setNodeMarkup(offset, undefined, attrs, node.marks)
    }
  })

  if (changed) {
    editor.view.dispatch(transaction)
  }
  return changed
}

export default function App() {
  const pageIdRef = useRef('page-1')
  const sendingUpdateRef = useRef(false)
  const debounceRef = useRef(null)
  const detachBridgeWaitRef = useRef(null)
  const detachMessageListenerRef = useRef(null)
  const [theme, setTheme] = useState('light')
  const [slashOpen, setSlashOpen] = useState(false)

  const extensions = useMemo(
    () => [
      StarterKit.configure({
        paragraph: false,
        heading: false,
        blockquote: false,
        bulletList: false,
        orderedList: false,
        listItem: false,
        horizontalRule: false,
      }),
      ParagraphNode,
      HeadingNode,
      BlockquoteNode,
      BulletListNode,
      OrderedListNode,
      ListItem,
      HorizontalRuleNode,
      IdocBlockNode,
    ],
    [],
  )

  const editor = useEditor({
    extensions,
    content: blankDoc,
    autofocus: false,
    editorProps: {
      attributes: {
        class: 'idoc-editor-surface',
      },
      handlePaste(view, event) {
        const imageFile = clipboardImageFile(event)
        if (!imageFile) {
          return false
        }
        event.preventDefault()
        void postClipboardImageToFlutter(imageFile)
        return true
      },
    },
    onCreate({ editor }) {
      normalizeTopLevelIds(editor)
      requestAnimationFrame(() => notifyFlutterEditorReady(editor))
    },
    onSelectionUpdate({ editor }) {
      postSelection(editor)
      setSlashOpen(isSlashTriggerActive(editor))
    },
    onUpdate({ editor }) {
      if (sendingUpdateRef.current) {
        return
      }
      if (normalizeTopLevelIds(editor)) {
        return
      }
      setSlashOpen(isSlashTriggerActive(editor))
      if (debounceRef.current) {
        window.clearTimeout(debounceRef.current)
      }
      debounceRef.current = window.setTimeout(() => {
        postToFlutter({
          type: 'pageBodyChanged',
          payload: {
            pageId: pageIdRef.current,
            doc: editor.getJSON(),
          },
        })
      }, 120)
    },
  })

  useEffect(() => {
    if (!editor) {
      return undefined
    }

    const handler = event => {
      const message = readFlutterMessage(event)
      if (!message) {
        return
      }
      const payload = message.payload ?? {}
      switch (message.type) {
        case 'loadPageBody':
        case 'replacePageBody': {
          const preserveSelection = payload.preserveSelection === true
          const currentSelectedId = preserveSelection ? selectedElementId(editor) : null
          sendingUpdateRef.current = true
          pageIdRef.current = payload.pageId || 'page-1'
          editor.commands.setContent(payload.doc || blankDoc, false)
          requestAnimationFrame(() => {
            sendingUpdateRef.current = false
            const nextSelectedId = payload.selectedElementId || currentSelectedId
            if (nextSelectedId) {
              selectElementById(editor, nextSelectedId)
            }
            postSelection(editor)
          })
          break
        }
        case 'focusEditor':
          editor.commands.focus()
          break
        case 'applyTextStyle':
          applyStyle(editor, payload.style || 'paragraph')
          break
        case 'applyFontSize':
          applyFontSize(
            editor,
            typeof payload.fontSize === 'number' ? payload.fontSize : null,
          )
          break
        case 'insertBlock':
          ensureSelection(editor)
          editor.chain().focus().insertContent({
            type: 'idocBlock',
            attrs: {
              elementId: payload.elementId,
              elementType: payload.elementType,
              width: typeof payload.width === 'number' ? payload.width : 1,
              preview: payload.preview || '',
              imageSrc: payload.imageSrc || '',
              imageAlt: payload.imageAlt || '',
            },
          }).run()
          postSelection(editor)
          break
        case 'setTheme':
          setTheme(payload.theme === 'dark' ? 'dark' : 'light')
          break
        case 'selectElement':
          selectElementById(editor, payload.elementId, payload.focus !== false)
          break
        default:
          break
      }
    }

    detachBridgeWaitRef.current?.()
    detachMessageListenerRef.current?.()

    detachBridgeWaitRef.current = waitForFlutterBridge(() => {
      if (!window.chrome?.webview) {
        return
      }
      window.chrome.webview.addEventListener('message', handler)
      detachMessageListenerRef.current = () => {
        window.chrome?.webview?.removeEventListener('message', handler)
      }
      notifyFlutterEditorReady(editor)
    })

    return () => {
      detachBridgeWaitRef.current?.()
      detachBridgeWaitRef.current = null
      detachMessageListenerRef.current?.()
      detachMessageListenerRef.current = null
    }
  }, [editor])

  useEffect(() => {
    document.documentElement.dataset.theme = theme
  }, [theme])

  if (!editor) {
    return <div className="idoc-editor-loading">Loading editor...</div>
  }

  return (
    <div className="idoc-editor-root">
      <EditorContent editor={editor} />
      {slashOpen ? (
        <div className="idoc-slash-menu">
          <div className="idoc-slash-title">Write or insert</div>
          <div className="idoc-slash-grid">
            {slashItems.map(item => (
              <button
                key={item.value}
                type="button"
                className="idoc-slash-item"
                onMouseDown={event => event.preventDefault()}
                onClick={() => {
                  clearSlashTrigger(editor)
                  if (item.value.startsWith('heading') ||
                      item.value === 'paragraph' ||
                      item.value === 'quote' ||
                      item.value.startsWith('list-')) {
                    applyStyle(editor, item.value)
                    postSelection(editor)
                    return
                  }
                  postToFlutter({
                    type: 'requestInsertBlock',
                    payload: { elementType: item.value },
                  })
                }}
              >
                {item.label}
              </button>
            ))}
          </div>
        </div>
      ) : null}
    </div>
  )
}

function postToFlutter(message) {
  if (window.chrome?.webview?.postMessage) {
    window.chrome.webview.postMessage(JSON.stringify(message))
  }
}

function notifyFlutterEditorReady(editor) {
  waitForFlutterBridge(() => {
    if (!hasFlutterBridge()) {
      return
    }
    postToFlutter({ type: 'editorReady' })
    postSelection(editor)
  })
}

function selectedElementId(editor) {
  const info = findTopLevelNodeSelection(editor)
  return info?.node?.attrs?.elementId || null
}

function postSelection(editor) {
  postToFlutter({
    type: 'selectionChanged',
    payload: {
      selectedElementId: selectedElementId(editor),
      textStyle: currentTextStyle(editor),
    },
  })
}

function selectElementById(editor, elementId, focus = true) {
  if (!elementId) {
    return false
  }
  const found = findElementNodePosition(editor, elementId)
  if (!found) {
    return false
  }
  const { node, pos } = found
  let selection = null
  if (node.type.name === 'idocBlock' || node.type.name === 'horizontalRule') {
    selection = NodeSelection.create(editor.state.doc, pos)
  } else {
    selection = TextSelection.near(editor.state.doc.resolve(Math.min(pos + 1, editor.state.doc.content.size)))
  }
  const transaction = editor.state.tr.setSelection(selection)
  editor.view.dispatch(transaction)
  if (focus) {
    editor.commands.focus()
  }
  postSelection(editor)
  return true
}
