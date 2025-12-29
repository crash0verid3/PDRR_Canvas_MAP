#!/usr/bin/env bash
set -e

PROJECT_DIR="pdrr_canvas"

download_file() {
  local url="$1"
  local dest="$2"

  echo "[*] Downloading $url -> $dest"
  if command -v curl >/dev/null 2>&1; then
    curl -L -o "$dest" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$dest" "$url"
  else
    echo "ERROR: Neither curl nor wget is available. Please install one of them."
    exit 1
  fi
}

echo "[*] Creating project directory: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo "[*] Writing requirements.txt"
cat << 'EOF' > requirements.txt
Flask>=3.0.0
EOF

echo "[*] Creating directory structure"
mkdir -p templates
mkdir -p static/js
mkdir -p static/css
mkdir -p data

echo "[*] Downloading JS libraries for offline use"
# Konva
if [ ! -f "static/js/konva.min.js" ]; then
  download_file "https://unpkg.com/konva@9/konva.min.js" "static/js/konva.min.js"
else
  echo "[*] static/js/konva.min.js already exists, skipping download"
fi

# jsPDF UMD
if [ ! -f "static/js/jspdf.umd.min.js" ]; then
  download_file "https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js" "static/js/jspdf.umd.min.js"
else
  echo "[*] static/js/jspdf.umd.min.js already exists, skipping download"
fi

echo "[*] Writing app.py"
cat << 'EOF' > app.py
import os
import json
from flask import Flask, render_template, request, jsonify

app = Flask(__name__)

DATA_DIR = os.path.join(app.root_path, "data")
os.makedirs(DATA_DIR, exist_ok=True)
SAVE_PATH = os.path.join(DATA_DIR, "saved_diagram.json")


@app.route("/")
def index():
  return render_template("canvas.html")


@app.route("/api/save", methods=["POST"])
def save_diagram():
  data = request.get_json(silent=True) or {}
  diagram = data.get("diagram")
  name = data.get("name") or "Default Diagram"

  if not diagram:
    return jsonify({"ok": False, "error": "No diagram provided"}), 400

  payload = {
    "name": name,
    "diagram": diagram,
  }

  with open(SAVE_PATH, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)

  return jsonify({"ok": True, "name": name})


@app.route("/api/load", methods=["GET"])
def load_diagram():
  if not os.path.exists(SAVE_PATH):
    return jsonify({"ok": False, "error": "No saved diagram found"}), 404

  with open(SAVE_PATH, "r", encoding="utf-8") as f:
    payload = json.load(f)

  return jsonify({
    "ok": True,
    "name": payload.get("name", "Default Diagram"),
    "diagram": payload.get("diagram", "")
  })


if __name__ == "__main__":
  app.run(host="0.0.0.0", port=5000, debug=True)
EOF

echo "[*] Writing templates/canvas.html"
cat << 'EOF' > templates/canvas.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>PDRR Storyboard Canvas</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <!-- Local Konva & jsPDF for offline use -->
  <script src="{{ url_for('static', filename='js/konva.min.js') }}"></script>
  <script src="{{ url_for('static', filename='js/jspdf.umd.min.js') }}"></script>
  <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
</head>
<body class="dark-theme">
  <div id="app-root">
    <header id="topbar">
      <div class="title">PDRR Storyboard Canvas</div>
      <div class="controls">
        <input id="diagramName" type="text" placeholder="Diagram name..." />
        <button onclick="newDiagram()">New</button>
        <button onclick="saveLocal()">Save Local JSON</button>
        <label class="file-label">
          Load Local JSON
          <input type="file" id="localFileInput" accept=".json">
        </label>
        <button onclick="saveServer()">Save to Server</button>
        <button onclick="loadServer()">Load from Server</button>
        <button onclick="exportJPEG()">Export JPEG</button>
        <button onclick="exportPDF()">Export PDF</button>

        <span class="divider"></span>

        <button id="connectBtn" onclick="toggleConnectMode()">Connect Nodes</button>

        <span class="divider"></span>

        <label class="color-label">
          Shape Color:
          <input type="color" id="colorPicker" value="#2563eb">
        </label>
        <button onclick="applyColor()">Apply Shape Color</button>

        <label class="color-label">
          Text Color:
          <input type="color" id="textColorPicker" value="#000000">
        </label>
        <button onclick="applyTextColor()">Apply Text Color</button>

        <span class="divider"></span>

        <div class="align-controls">
          <span>Text Align:</span>
          <button onclick="setTextAlign('left')">L</button>
          <button onclick="setTextAlign('center')">C</button>
          <button onclick="setTextAlign('right')">R</button>
        </div>

        <span class="divider"></span>

        <div class="font-controls">
          <span>Font Size:</span>
          <input type="number" id="fontSizeInput" min="8" max="48" value="12" />
          <button onclick="applyFontSize()">Apply</button>
        </div>

        <span class="divider"></span>

        <button id="themeToggleBtn" onclick="toggleTheme()">Light UI</button>
      </div>
    </header>

    <div id="main">
      <aside id="palette">
        <h3>Blue Team</h3>
        <button onclick="addBluePerson()">Blue Person</button>
        <button onclick="addBlueLaptop()">Blue Laptop</button>
        <button onclick="addBlueServer()">Blue Server</button>
        <button onclick="addBlueDatabase()">Blue Database</button>
        <button onclick="addBlueAlert()">Alert / Detection</button>

        <h3>Red Team</h3>
        <button onclick="addRedPerson()">Red Person</button>
        <button onclick="addRedLaptop()">Red Laptop</button>
        <button onclick="addRedServer()">Red Server</button>
        <button onclick="addRedDatabase()">Red Database</button>

        <h3>PDRR Phases</h3>
        <button onclick="addPrepareEvent()">Prepare Event</button>
        <button onclick="addDetectEvent()">Detect Event</button>
        <button onclick="addRespondEvent()">Respond Event</button>
        <button onclick="addRecoverEvent()">Recover Event</button>

        <h3>White Cards</h3>
        <button onclick="addWhiteCard()">White Card</button>

        <h3>Annotations</h3>
        <button onclick="addTextBubble()">Text Bubble</button>
        <button onclick="addPlainLabel()">Plain Label</button>

        <div class="hint">
          • Double-click any text to edit it.<br>
          • Double-click a connector line or its label to add/edit label text.<br>
          • Use "Connect Nodes" to draw event chains.<br>
          • Use the color pickers to recolor shapes and text.<br>
          • Use L/C/R buttons or right-click menu to align text.<br>
          • Use font size controls (top bar or right-click) to resize text.<br>
          • Right-click an item for Delete / Colors / Alignment / Font Size.<br>
          • Delete/Backspace also deletes selected items.<br>
          • Snap-to-grid keeps items aligned cleanly.
        </div>
      </aside>

      <section id="canvas-wrapper">
        <div id="container"></div>
      </section>
    </div>
  </div>

  <!-- Context menu for right-click -->
  <div id="context-menu">
    <div class="cm-section">
      <button onclick="cmDelete()">Delete</button>
    </div>
    <div class="cm-section">
      <div>Shape Color:</div>
      <input type="color" id="cmShapeColor" value="#2563eb">
      <button onclick="cmApplyShapeColor()">Apply</button>
    </div>
    <div class="cm-section">
      <div>Text Color:</div>
      <input type="color" id="cmTextColor" value="#000000">
      <button onclick="cmApplyTextColor()">Apply</button>
    </div>
    <div class="cm-section">
      <div>Text Align:</div>
      <button onclick="cmAlign('left')">L</button>
      <button onclick="cmAlign('center')">C</button>
      <button onclick="cmAlign('right')">R</button>
    </div>
    <div class="cm-section">
      <div>Font Size:</div>
      <input type="number" id="cmFontSize" min="8" max="48" value="12">
      <button onclick="cmApplyFontSize()">Apply</button>
    </div>
  </div>

  <script src="{{ url_for('static', filename='js/main.js') }}"></script>
</body>
</html>
EOF

echo "[*] Writing static/css/style.css"
cat << 'EOF' > static/css/style.css
* {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

/* DARK THEME (default) */
body.dark-theme {
  background: #1f2933;
  color: #f9fafb;
}

/* LIGHT THEME */
body.light-theme {
  background: #f9fafb;
  color: #111827;
}

#app-root {
  display: flex;
  flex-direction: column;
  height: 100vh;
}

#topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 10px;
  background: #111827;
  border-bottom: 1px solid #374151;
}

#topbar .title {
  font-weight: 600;
  font-size: 16px;
}

#topbar .controls {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
}

#topbar input[type="text"] {
  padding: 4px 6px;
  border-radius: 4px;
  border: 1px solid #4b5563;
  background: #111827;
  color: #e5e7eb;
  min-width: 150px;
}

#topbar button {
  padding: 4px 8px;
  border-radius: 4px;
  border: 1px solid #4b5563;
  background: #111827;
  color: #e5e7eb;
  cursor: pointer;
  font-size: 12px;
}

#topbar button:hover {
  background: #1f2933;
}

#topbar button.active {
  background: #2563eb;
  border-color: #2563eb;
}

.file-label {
  position: relative;
  overflow: hidden;
  display: inline-flex;
  align-items: center;
  padding: 4px 8px;
  border-radius: 4px;
  border: 1px solid #4b5563;
  background: #111827;
  color: #e5e7eb;
  cursor: pointer;
  font-size: 12px;
}

.file-label input[type="file"] {
  position: absolute;
  left: 0;
  top: 0;
  opacity: 0;
  cursor: pointer;
}

.color-label {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
}

.color-label input[type="color"] {
  width: 32px;
  height: 22px;
  padding: 0;
  border-radius: 4px;
  border: 1px solid #4b5563;
  background: transparent;
}

.divider {
  width: 1px;
  height: 24px;
  background: #4b5563;
  margin: 0 4px;
}

.align-controls {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
}

.align-controls button {
  width: 24px;
  text-align: center;
  padding: 2px;
}

.font-controls {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
}

.font-controls input[type="number"] {
  width: 52px;
  padding: 2px 4px;
  border-radius: 4px;
  border: 1px solid #4b5563;
  background: #111827;
  color: #e5e7eb;
}

#main {
  flex: 1;
  display: flex;
  min-height: 0;
}

#palette {
  width: 220px;
  padding: 8px;
  background: #111827;
  border-right: 1px solid #374151;
  overflow-y: auto;
  color: #f9fafb;
}

#palette h3 {
  margin: 10px 0 4px;
  font-size: 13px;
  text-transform: uppercase;
  color: #9ca3af;
}

#palette button {
  width: 100%;
  margin-bottom: 4px;
  padding: 5px 8px;
  background: #1f2933;
  border: 1px solid #374151;
  border-radius: 4px;
  color: #e5e7eb;
  cursor: pointer;
  font-size: 12px;
  text-align: left;
}

#palette button:hover {
  background: #374151;
}

#palette .hint {
  margin-top: 8px;
  font-size: 11px;
  color: #9ca3af;
}

#canvas-wrapper {
  flex: 1;
  position: relative;
  background: #111827;
  overflow: auto;
}

#container {
  width: 100%;
  height: 100%;
}

/* Konva canvas background – keep white so exports & view match */
#container canvas {
  background-color: #ffffff;
}

/* Context menu */
#context-menu {
  position: fixed;
  background: #111827;
  color: #e5e7eb;
  border: 1px solid #4b5563;
  padding: 6px;
  border-radius: 4px;
  font-size: 12px;
  display: none;
  z-index: 9999;
  min-width: 200px;
}

#context-menu .cm-section {
  margin-bottom: 6px;
  border-bottom: 1px solid #374151;
  padding-bottom: 4px;
}

#context-menu .cm-section:last-child {
  border-bottom: none;
  margin-bottom: 0;
  padding-bottom: 0;
}

#context-menu button {
  margin-top: 2px;
  padding: 2px 6px;
  border-radius: 3px;
  border: 1px solid #4b5563;
  background: #1f2933;
  color: #e5e7eb;
  cursor: pointer;
  font-size: 11px;
}

#context-menu button:hover {
  background: #374151;
}

#context-menu input[type="color"] {
  width: 32px;
  height: 18px;
  padding: 0;
  border-radius: 3px;
  border: 1px solid #4b5563;
  background: transparent;
}

#context-menu input[type="number"] {
  width: 60px;
  padding: 2px 4px;
  border-radius: 3px;
  border: 1px solid #4b5563;
  background: #111827;
  color: #e5e7eb;
}

/* LIGHT THEME OVERRIDES */
body.light-theme #topbar {
  background: #e5e7eb;
  border-bottom: 1px solid #d1d5db;
}

body.light-theme #topbar .title {
  color: #111827;
}

body.light-theme #topbar input[type="text"] {
  background: #ffffff;
  border-color: #d1d5db;
  color: #111827;
}

body.light-theme #topbar button,
body.light-theme .file-label {
  background: #e5e7eb;
  border-color: #d1d5db;
  color: #111827;
}

body.light-theme #topbar button:hover {
  background: #d1d5db;
}

body.light-theme #palette {
  background: #f3f4f6;
  border-right: 1px solid #d1d5db;
  color: #111827;
}

body.light-theme #palette h3 {
  color: #4b5563;
}

body.light-theme #palette button {
  background: #e5e7eb;
  border-color: #d1d5db;
  color: #111827;
}

body.light-theme #palette button:hover {
  background: #d1d5db;
}

body.light-theme #palette .hint {
  color: #6b7280;
}

body.light-theme #canvas-wrapper {
  background: #e5e7eb;
}

body.light-theme #context-menu {
  background: #e5e7eb;
  color: #111827;
  border-color: #d1d5db;
}

body.light-theme #context-menu .cm-section {
  border-bottom-color: #d1d5db;
}

body.light-theme #context-menu button {
  background: #f3f4f6;
  border-color: #d1d5db;
  color: #111827;
}

body.light-theme #context-menu button:hover {
  background: #e5e7eb;
}

body.light-theme #context-menu input[type="number"] {
  background: #ffffff;
  border-color: #d1d5db;
  color: #111827;
}

/* PRINT-OPTIMIZED LAYOUT */
@media print {
  #topbar,
  #palette,
  #context-menu {
    display: none !important;
  }

  body {
    background: #ffffff !important;
  }

  #canvas-wrapper {
    position: static;
    margin: 0;
    padding: 0;
  }

  #container {
    width: 100vw;
    height: 100vh;
  }
}
EOF

echo "[*] Writing static/js/main.js"
cat << 'EOF' > static/js/main.js
// Global Konva objects and state
let stage;
let layer;
let connections = [];
let connecting = false;
let pendingNode = null;
let nodeCounter = 1;
let selectedElement = null;
let selectedElementType = null;
let transformer;
let arrowCounter = 1;

// Context menu state
let contextTarget = null;
let contextTargetType = null;

// Canvas size & grid
const CANVAS_WIDTH = 2200;
const CANVAS_HEIGHT = 1600;
const GRID_SIZE = 20;

// Ensure a white background rect exists in the layer, so view & exports are white
function addBackgroundIfMissing() {
  if (!layer) return;

  let bg = layer.findOne('Rect[isBackground=true]');
  if (!bg) {
    bg = new Konva.Rect({
      x: 0,
      y: 0,
      width: CANVAS_WIDTH,
      height: CANVAS_HEIGHT,
      fill: "#ffffff",
      listening: false,
    });
    bg.setAttr("isBackground", true);
    layer.add(bg);
  }
  bg.width(CANVAS_WIDTH);
  bg.height(CANVAS_HEIGHT);
  bg.moveToBottom();
}

function initStage() {
  stage = new Konva.Stage({
    container: "container",
    width: CANVAS_WIDTH,
    height: CANVAS_HEIGHT,
  });

  layer = new Konva.Layer();
  stage.add(layer);

  addBackgroundIfMissing();
  createTransformer();
}

function createTransformer() {
  transformer = new Konva.Transformer({
    rotateEnabled: false,
    enabledAnchors: [
      "top-left",
      "top-right",
      "bottom-left",
      "bottom-right",
      "middle-left",
      "middle-right",
      "top-center",
      "bottom-center",
    ],
    boundBoxFunc: (oldBox, newBox) => {
      if (newBox.width < 20 || newBox.height < 20) {
        return oldBox;
      }
      return newBox;
    },
  });

  layer.add(transformer);
}

function clearSelectionHighlight() {
  if (!selectedElement) {
    transformer.nodes([]);
    return;
  }

  if (selectedElementType === "node") {
    selectedElement.getChildren().forEach((child) => {
      if (child instanceof Konva.Shape) {
        child.shadowBlur(0);
        child.shadowOpacity(0);
      }
    });
  } else if (selectedElementType === "arrow") {
    selectedElement.shadowBlur(0);
    selectedElement.shadowOpacity(0);
  }

  selectedElement = null;
  selectedElementType = null;
  transformer.nodes([]);
}

function highlightNode(group) {
  group.getChildren().forEach((child) => {
    if (child instanceof Konva.Shape) {
      child.shadowColor("#111827");
      child.shadowBlur(10);
      child.shadowOpacity(0.7);
    }
  });
  transformer.nodes([group]);
}

function highlightArrow(arrow) {
  arrow.shadowColor("#111827");
  arrow.shadowBlur(10);
  arrow.shadowOpacity(0.7);
  transformer.nodes([]);
}

function registerNode(group, type) {
  group.setAttr("nodeType", type);
  if (!group.getAttr("nodeId")) {
    group.setAttr("nodeId", "node-" + nodeCounter++);
  }

  // Snap-to-grid while dragging
  group.on("dragmove", () => {
    const pos = group.position();
    const snappedX = Math.round(pos.x / GRID_SIZE) * GRID_SIZE;
    const snappedY = Math.round(pos.y / GRID_SIZE) * GRID_SIZE;
    group.position({ x: snappedX, y: snappedY });
    updateConnectionsFor(group);
  });

  group.on("transformend", () => {
    updateConnectionsFor(group);
  });

  group.on("dblclick", (evt) => {
    const nodeType = group.getAttr("nodeType");
    const isEventType =
      nodeType === "prepare" ||
      nodeType === "detect" ||
      nodeType === "respond" ||
      nodeType === "recover" ||
      nodeType === "white_card";

    let targetText = null;

    if (evt.target && evt.target instanceof Konva.Text) {
      targetText = evt.target;
    } else if (isEventType) {
      targetText =
        group.findOne('Text[textRole="body"]') ||
        group.findOne("Text");
    } else {
      targetText = group.findOne("Text");
    }

    if (!targetText) return;

    const current = targetText.text();
    const updated = prompt("Edit text:", current);
    if (updated !== null) {
      targetText.text(updated);
      layer.draw();
    }
  });
}

function computeEdgePoint(center, v, box) {
  const hw = box.width / 2;
  const hh = box.height / 2;

  const dx = v.x;
  const dy = v.y;

  if (dx === 0 && dy === 0) {
    return center;
  }

  const tX = dx !== 0 ? hw / Math.abs(dx) : Infinity;
  const tY = dy !== 0 ? hh / Math.abs(dy) : Infinity;
  const t = Math.min(tX, tY);

  if (!isFinite(t) || t <= 0) {
    return center;
  }

  return {
    x: center.x + dx * t,
    y: center.y + dy * t,
  };
}

function getEdgePoints(fromGroup, toGroup) {
  const fromBox = fromGroup.getClientRect();
  const toBox = toGroup.getClientRect();

  const fromCenter = {
    x: fromBox.x + fromBox.width / 2,
    y: fromBox.y + fromBox.height / 2,
  };
  const toCenter = {
    x: toBox.x + toBox.width / 2,
    y: toBox.y + toBox.height / 2,
  };

  const v1 = {
    x: toCenter.x - fromCenter.x,
    y: toCenter.y - fromCenter.y,
  };
  const start = computeEdgePoint(fromCenter, v1, fromBox);

  const v2 = {
    x: fromCenter.x - toCenter.x,
    y: fromCenter.y - toCenter.y,
  };
  const end = computeEdgePoint(toCenter, v2, toBox);

  return { start, end };
}

/* ---- BLUE TEAM ICONS (Person / Laptop / Server / Database / Alert) ---- */

function addBluePerson() {
  const group = new Konva.Group({
    x: 80,
    y: 80,
    draggable: true,
  });

  const head = new Konva.Circle({
    x: 25,
    y: 15,
    radius: 10,
    fill: "#2563eb",
    stroke: "#111827",
    strokeWidth: 2,
  });

  const body = new Konva.Rect({
    x: 17,
    y: 25,
    width: 16,
    height: 24,
    fill: "#2563eb",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 4,
  });

  const text = new Konva.Text({
    text: "Blue\nPerson",
    fontSize: 11,
    fill: "#111827",
    align: "center",
    width: 60,
    x: -5,
    y: 55,
  });

  group.add(head);
  group.add(body);
  group.add(text);
  layer.add(group);
  registerNode(group, "blue_person");
  layer.draw();
}

function addBlueLaptop() {
  const group = new Konva.Group({
    x: 180,
    y: 80,
    draggable: true,
  });

  const screen = new Konva.Rect({
    x: 5,
    y: 5,
    width: 50,
    height: 30,
    fill: "#1d4ed8",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 3,
  });

  const base = new Konva.Rect({
    x: 0,
    y: 35,
    width: 60,
    height: 8,
    fill: "#2563eb",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 2,
  });

  const text = new Konva.Text({
    text: "Blue Laptop",
    fontSize: 11,
    fill: "#111827",
    align: "center",
    width: 70,
    x: -5,
    y: 50,
  });

  group.add(screen);
  group.add(base);
  group.add(text);
  layer.add(group);
  registerNode(group, "blue_laptop");
  layer.draw();
}

function addBlueServer() {
  const group = new Konva.Group({
    x: 280,
    y: 70,
    draggable: true,
  });

  const tower = new Konva.Rect({
    x: 0,
    y: 0,
    width: 40,
    height: 70,
    fill: "#1d4ed8",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 4,
  });

  const slot1 = new Konva.Rect({
    x: 5,
    y: 10,
    width: 30,
    height: 4,
    fill: "#bfdbfe",
  });

  const slot2 = slot1.clone({ y: 22 });
  const slot3 = slot1.clone({ y: 34 });

  const text = new Konva.Text({
    text: "Blue\nServer",
    fontSize: 11,
    fill: "#111827",
    align: "center",
    width: 60,
    x: -10,
    y: 75,
  });

  group.add(tower);
  group.add(slot1);
  group.add(slot2);
  group.add(slot3);
  group.add(text);
  layer.add(group);
  registerNode(group, "blue_server");
  layer.draw();
}

function addBlueDatabase() {
  const group = new Konva.Group({
    x: 380,
    y: 80,
    draggable: true,
  });

  const topEllipse = new Konva.Ellipse({
    x: 35,
    y: 15,
    radiusX: 30,
    radiusY: 10,
    fill: "#1d4ed8",
    stroke: "#111827",
    strokeWidth: 2,
  });

  const bodyRect = new Konva.Rect({
    x: 5,
    y: 15,
    width: 60,
    height: 35,
    fill: "#1d4ed8",
    stroke: "#111827",
    strokeWidth: 2,
  });

  const bottomEllipse = new Konva.Ellipse({
    x: 35,
    y: 50,
    radiusX: 30,
    radiusY: 10,
    fill: "#1d4ed8",
    stroke: "#111827",
    strokeWidth: 2,
  });

  const text = new Konva.Text({
    text: "Blue DB",
    fontSize: 11,
    fill: "#111827",
    align: "center",
    width: 70,
    x: 0,
    y: 65,
  });

  group.add(bodyRect);
  group.add(topEllipse);
  group.add(bottomEllipse);
  group.add(text);
  layer.add(group);
  registerNode(group, "blue_database");
  layer.draw();
}

function addBlueAlert() {
  const group = new Konva.Group({
    x: 490,
    y: 80,
    draggable: true,
  });

  const diamond = new Konva.Rect({
    width: 60,
    height: 60,
    fill: "#f97316",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 4,
    rotation: 45,
  });

  const text = new Konva.Text({
    text: "Alert",
    fontSize: 12,
    fill: "#111827",
    align: "center",
    width: 60,
    offsetX: 30,
    offsetY: -6,
  });

  group.add(diamond);
  group.add(text);
  registerNode(group, "blue_alert");
  layer.add(group);
  layer.draw();
}

/* ---- RED TEAM ICONS (Person / Laptop / Server / Database) ---- */

function addRedPerson() {
  const group = new Konva.Group({
    x: 80,
    y: 200,
    draggable: true,
  });

  const head = new Konva.Circle({
    x: 25,
    y: 15,
    radius: 10,
    fill: "#dc2626",
    stroke: "#111827",
    strokeWidth: 2,
  });

  const body = new Konva.Rect({
    x: 17,
    y: 25,
    width: 16,
    height: 24,
    fill: "#dc2626",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 4,
  });

  const text = new Konva.Text({
    text: "Red\nPerson",
    fontSize: 11,
    fill: "#111827",
    align: "center",
    width: 60,
    x: -5,
    y: 55,
  });

  group.add(head);
  group.add(body);
  group.add(text);
  layer.add(group);
  registerNode(group, "red_person");
  layer.draw();
}

function addRedLaptop() {
  const group = new Konva.Group({
    x: 180,
    y: 200,
    draggable: true,
  });

  const screen = new Konva.Rect({
    x: 5,
    y: 5,
    width: 50,
    height: 30,
    fill: "#b91c1c",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 3,
  });

  const base = new Konva.Rect({
    x: 0,
    y: 35,
    width: 60,
    height: 8,
    fill: "#dc2626",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 2,
  });

  const text = new Konva.Text({
    text: "Red Laptop",
    fontSize: 11,
    fill: "#111827",
    align: "center",
    width: 70,
    x: -5,
    y: 50,
  });

  group.add(screen);
  group.add(base);
  group.add(text);
  layer.add(group);
  registerNode(group, "red_laptop");
  layer.draw();
}

function addRedServer() {
  const group = new Konva.Group({
    x: 280,
    y: 190,
    draggable: true,
  });

  const tower = new Konva.Rect({
    x: 0,
    y: 0,
    width: 40,
    height: 70,
    fill: "#b91c1c",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 4,
  });

  const slot1 = new Konva.Rect({
    x: 5,
    y: 10,
    width: 30,
    height: 4,
    fill: "#fecaca",
  });
  const slot2 = slot1.clone({ y: 22 });
  const slot3 = slot1.clone({ y: 34 });

  const text = new Konva.Text({
    text: "Red\nServer",
    fontSize: 11,
    fill: "#111827",
    align: "center",
    width: 60,
    x: -10,
    y: 75,
  });

  group.add(tower);
  group.add(slot1);
  group.add(slot2);
  group.add(slot3);
  group.add(text);
  layer.add(group);
  registerNode(group, "red_server");
  layer.draw();
}

function addRedDatabase() {
  const group = new Konva.Group({
    x: 380,
    y: 200,
    draggable: true,
  });

  const topEllipse = new Konva.Ellipse({
    x: 35,
    y: 15,
    radiusX: 30,
    radiusY: 10,
    fill: "#b91c1c",
    stroke: "#111827",
    strokeWidth: 2,
  });

  const bodyRect = new Konva.Rect({
    x: 5,
    y: 15,
    width: 60,
    height: 35,
    fill: "#b91c1c",
    stroke: "#111827",
    strokeWidth: 2,
  });

  const bottomEllipse = new Konva.Ellipse({
    x: 35,
    y: 50,
    radiusX: 30,
    radiusY: 10,
    fill: "#b91c1c",
    stroke: "#111827",
    strokeWidth: 2,
  });

  const text = new Konva.Text({
    text: "Red DB",
    fontSize: 11,
    fill: "#111827",
    align: "center",
    width: 70,
    x: 0,
    y: 65,
  });

  group.add(bodyRect);
  group.add(topEllipse);
  group.add(bottomEllipse);
  group.add(text);
  layer.add(group);
  registerNode(group, "red_database");
  layer.draw();
}

/* ---- PDRR EVENTS ---- */

function createPhaseEvent(x, y, color, header, type) {
  const group = new Konva.Group({
    x,
    y,
    draggable: true,
  });

  const rect = new Konva.Rect({
    width: 220,
    height: 80,
    fill: color,
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 6,
  });

  const headerText = new Konva.Text({
    text: header,
    fontSize: 13,
    fontStyle: "bold",
    fill: "#111827",
    x: 8,
    y: 4,
    align: "left",
    width: 204,
  });
  headerText.setAttr("textRole", "header");

  const bodyText = new Konva.Text({
    text: `Describe ${header} event`,
    fontSize: 11,
    fill: "#111827",
    x: 8,
    y: 24,
    width: 204,
    align: "center",
  });
  bodyText.setAttr("textRole", "body");

  group.add(rect);
  group.add(headerText);
  group.add(bodyText);
  registerNode(group, type);
  layer.add(group);
  layer.draw();
}

function addPrepareEvent() {
  createPhaseEvent(650, 60, "#a855f7", "Prepare", "prepare");
}

function addDetectEvent() {
  createPhaseEvent(650, 170, "#facc15", "Detect", "detect");
}

function addRespondEvent() {
  createPhaseEvent(650, 280, "#22c55e", "Respond", "respond");
}

function addRecoverEvent() {
  createPhaseEvent(650, 390, "#14b8a6", "Recover", "recover");
}

/* ---- WHITE CARD EVENT ---- */

function addWhiteCard() {
  const group = new Konva.Group({
    x: 650,
    y: 500,
    draggable: true,
  });

  const rect = new Konva.Rect({
    width: 260,
    height: 100,
    fill: "#ffffff",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 6,
  });

  const headerText = new Konva.Text({
    text: "White Card",
    fontSize: 13,
    fontStyle: "bold",
    fill: "#111827",
    x: 8,
    y: 4,
    align: "left",
    width: 244,
  });
  headerText.setAttr("textRole", "header");

  const bodyText = new Konva.Text({
    text: "Describe what this White Card represents (scope change, rule tweak, inject, etc.).",
    fontSize: 11,
    fill: "#111827",
    x: 8,
    y: 24,
    width: 244,
    align: "center",
  });
  bodyText.setAttr("textRole", "body");

  group.add(rect);
  group.add(headerText);
  group.add(bodyText);
  registerNode(group, "white_card");
  layer.add(group);
  layer.draw();
}

/* ---- ANNOTATIONS ---- */

function addTextBubble() {
  const group = new Konva.Group({
    x: 100,
    y: 320,
    draggable: true,
  });

  const rect = new Konva.Rect({
    width: 260,
    height: 80,
    fill: "#ffffff",
    stroke: "#111827",
    strokeWidth: 2,
    cornerRadius: 8,
  });

  const text = new Konva.Text({
    text: "Narrative / takeaway. Include date/time, impact, and PDRR notes here.",
    fontSize: 12,
    fill: "#111827",
    x: 8,
    y: 8,
    width: 244,
    align: "center",
  });

  group.add(rect);
  group.add(text);
  registerNode(group, "bubble");
  layer.add(group);
  layer.draw();
}

function addPlainLabel() {
  const group = new Konva.Group({
    x: 100,
    y: 430,
    draggable: true,
  });

  const bg = new Konva.Rect({
    width: 180,
    height: 30,
    fill: "#f9fafb",
    stroke: "#111827",
    strokeWidth: 1,
    cornerRadius: 4,
  });

  const text = new Konva.Text({
    text: "Label (e.g. 2025-12-29 10:32Z)",
    fontSize: 12,
    fill: "#111827",
    x: 6,
    y: 7,
    width: 168,
    align: "center",
  });

  group.add(bg);
  group.add(text);
  registerNode(group, "label");
  layer.add(group);
  layer.draw();
}

/* ---- CONNECT MODE ---- */

function toggleConnectMode() {
  connecting = !connecting;
  pendingNode = null;
  const btn = document.getElementById("connectBtn");
  if (connecting) {
    btn.classList.add("active");
  } else {
    btn.classList.remove("active");
  }
}

function createConnection(fromGroup, toGroup) {
  const { start, end } = getEdgePoints(fromGroup, toGroup);

  const arrowId = "arrow-" + arrowCounter++;

  const arrow = new Konva.Arrow({
    points: [start.x, start.y, end.x, end.y],
    stroke: "#dc2626",
    fill: "#dc2626",
    strokeWidth: 2,
    pointerLength: 10,
    pointerWidth: 10,
  });

  arrow.setAttr("fromId", fromGroup.getAttr("nodeId"));
  arrow.setAttr("toId", toGroup.getAttr("nodeId"));
  arrow.setAttr("arrowId", arrowId);

  const midX = (start.x + end.x) / 2;
  const midY = (start.y + end.y) / 2;

  const label = new Konva.Text({
    text: "",
    fontSize: 11,
    fill: "#000000",
    x: midX - 60,
    y: midY - 10,
    width: 120,
    align: "center",
    listening: true,
  });

  label.setAttr("isConnectionLabel", true);
  label.setAttr("forArrowId", arrowId);

  const editLabel = (evt) => {
    evt.cancelBubble = true;
    const current = label.text() || "";
    const updated = prompt(
      "Connection label (e.g. TTP, log ref, etc.):",
      current
    );
    if (updated !== null) {
      label.text(updated);
      layer.draw();
    }
  };

  arrow.on("dblclick", editLabel);
  label.on("dblclick", editLabel);

  label.on("click", (evt) => {
    evt.cancelBubble = true;
    clearSelectionHighlight();
    selectedElement = arrow;
    selectedElementType = "arrow";
    highlightArrow(arrow);
    layer.draw();
  });

  layer.add(arrow);
  layer.add(label);

  const conn = {
    line: arrow,
    from: fromGroup,
    to: toGroup,
    label: label,
  };
  connections.push(conn);

  layer.draw();
}

function updateConnectionsFor(group) {
  connections.forEach((conn) => {
    if (conn.from === group || conn.to === group) {
      const { start, end } = getEdgePoints(conn.from, conn.to);
      conn.line.points([start.x, start.y, end.x, end.y]);

      if (conn.label) {
        const midX = (start.x + end.x) / 2;
        const midY = (start.y + end.y) / 2;
        conn.label.position({
          x: midX - conn.label.width() / 2,
          y: midY - conn.label.height() / 2,
        });
      }
    }
  });
  layer.draw();
}

function deleteSelected() {
  if (!selectedElement) return;

  if (selectedElementType === "node") {
    const group = selectedElement;

    connections = connections.filter((conn) => {
      if (conn.from === group || conn.to === group) {
        conn.line.destroy();
        if (conn.label) conn.label.destroy();
        return false;
      }
      return true;
    });

    group.destroy();
  } else if (selectedElementType === "arrow") {
    const arrow = selectedElement;

    connections = connections.filter((conn) => {
      if (conn.line === arrow) {
        if (conn.label) conn.label.destroy();
        return false;
      }
      return true;
    });

    arrow.destroy();
  }

  selectedElement = null;
  selectedElementType = null;
  transformer.nodes([]);
  layer.draw();
}

function setupStageClickHandler() {
  stage.on("click", (evt) => {
    hideContextMenu();

    const shape = evt.target;
    if (!shape) return;

    if (shape.getParent() && shape.getParent() instanceof Konva.Transformer) {
      return;
    }

    const isArrow = shape instanceof Konva.Arrow;
    const parent = shape.getParent();
    const group = parent && parent instanceof Konva.Group ? parent : null;

    if (connecting && group) {
      if (!pendingNode) {
        pendingNode = group;
      } else if (pendingNode === group) {
        pendingNode = null;
      } else {
        createConnection(pendingNode, group);
        pendingNode = null;
      }
    }

    clearSelectionHighlight();

    if (isArrow) {
      selectedElement = shape;
      selectedElementType = "arrow";
      highlightArrow(shape);
    } else if (
      shape instanceof Konva.Text &&
      shape.getAttr("isConnectionLabel")
    ) {
      const arrowKey = shape.getAttr("forArrowId");
      const arrow = stage.findOne('Arrow[arrowId="' + arrowKey + '"]');
      if (arrow) {
        selectedElement = arrow;
        selectedElementType = "arrow";
        highlightArrow(arrow);
      } else {
        selectedElement = null;
        selectedElementType = null;
      }
    } else if (group) {
      selectedElement = group;
      selectedElementType = "node";
      highlightNode(group);
    } else {
      selectedElement = null;
      selectedElementType = null;
    }

    layer.draw();
  });
}

function setupDomContextMenuHandler() {
  const container = stage.container();
  container.addEventListener("contextmenu", (e) => {
    e.preventDefault();

    const clientX = e.clientX;
    const clientY = e.clientY;

    const rect = container.getBoundingClientRect();
    const pointerPos = {
      x: clientX - rect.left,
      y: clientY - rect.top,
    };

    const shape = stage.getIntersection(pointerPos);
    if (!shape) {
      hideContextMenu();
      return;
    }

    let targetElement = null;
    let targetType = null;

    if (shape instanceof Konva.Arrow) {
      targetElement = shape;
      targetType = "arrow";
    } else if (
      shape instanceof Konva.Text &&
      shape.getAttr("isConnectionLabel")
    ) {
      const arrowKey = shape.getAttr("forArrowId");
      const arrow = stage.findOne('Arrow[arrowId="' + arrowKey + '"]');
      if (arrow) {
        targetElement = arrow;
        targetType = "arrow";
      }
    } else {
      const parent = shape.getParent();
      if (parent && parent instanceof Konva.Group) {
        targetElement = parent;
        targetType = "node";
      }
    }

    if (!targetElement) {
      hideContextMenu();
      return;
    }

    clearSelectionHighlight();
    selectedElement = targetElement;
    selectedElementType = targetType;

    if (targetType === "node") {
      highlightNode(targetElement);
    } else if (targetType === "arrow") {
      highlightArrow(targetElement);
    }

    contextTarget = targetElement;
    contextTargetType = targetType;

    const cmFontInput = document.getElementById("cmFontSize");
    if (selectedElementType === "node") {
      const t = selectedElement.findOne("Text");
      if (t) cmFontInput.value = t.fontSize();
    } else if (selectedElementType === "arrow") {
      const arrowKey = selectedElement.getAttr("arrowId");
      const label = layer.findOne('Text[forArrowId="' + arrowKey + '"]');
      if (label) cmFontInput.value = label.fontSize();
    }

    const menu = document.getElementById("context-menu");
    menu.style.display = "block";
    menu.style.left = clientX + "px";
    menu.style.top = clientY + "px";
    layer.draw();
  });
}

function hideContextMenu() {
  const menu = document.getElementById("context-menu");
  menu.style.display = "none";
  contextTarget = null;
  contextTargetType = null;
}

window.addEventListener("click", (e) => {
  const menu = document.getElementById("context-menu");
  if (menu && menu.style.display === "block" && menu.contains(e.target)) {
    return; // don't hide if clicking inside the menu
  }
  hideContextMenu();
});

// Context menu actions
function cmDelete() {
  if (!contextTarget) return;
  deleteSelected();
  hideContextMenu();
}

function cmApplyShapeColor() {
  if (!contextTarget) return;
  const color = document.getElementById("cmShapeColor").value;
  if (!color) return;

  if (selectedElementType === "node") {
    selectedElement.getChildren().forEach((child) => {
      if (child instanceof Konva.Shape && !(child instanceof Konva.Text)) {
        if (child.fill()) {
          child.fill(color);
        } else if (child.stroke()) {
          child.stroke(color);
        }
      }
    });
  } else if (selectedElementType === "arrow") {
    selectedElement.stroke(color);
    selectedElement.fill(color);
  }

  layer.draw();
}

function cmApplyTextColor() {
  if (!contextTarget) return;
  const color = document.getElementById("cmTextColor").value;
  if (!color) return;

  if (selectedElementType === "node") {
    selectedElement.find("Text").forEach((t) => {
      t.fill(color);
    });
  } else if (selectedElementType === "arrow") {
    const arrow = selectedElement;
    const arrowKey = arrow.getAttr("arrowId");
    const label = layer.findOne('Text[forArrowId="' + arrowKey + '"]');
    if (label) {
      label.fill(color);
    }
  }

  layer.draw();
}

function cmAlign(alignment) {
  if (!contextTarget || selectedElementType !== "node") return;
  selectedElement.find("Text").forEach((t) => {
    t.align(alignment);
  });
  layer.draw();
}

function cmApplyFontSize() {
  if (!contextTarget) return;
  const input = document.getElementById("cmFontSize");
  const size = parseInt(input.value, 10);
  if (isNaN(size) || size <= 0) return;

  if (selectedElementType === "node") {
    selectedElement.find("Text").forEach((t) => {
      t.fontSize(size);
    });
  } else if (selectedElementType === "arrow") {
    const arrow = selectedElement;
    const arrowKey = arrow.getAttr("arrowId");
    const label = layer.findOne('Text[forArrowId="' + arrowKey + '"]');
    if (label) {
      label.fontSize(size);
    }
  }

  layer.draw();
}

// Topbar shape color
function applyColor() {
  const color = document.getElementById("colorPicker").value;
  if (!selectedElement || !color) return;

  if (selectedElementType === "node") {
    selectedElement.getChildren().forEach((child) => {
      if (child instanceof Konva.Shape && !(child instanceof Konva.Text)) {
        if (child.fill()) {
          child.fill(color);
        } else if (child.stroke()) {
          child.stroke(color);
        }
      }
    });
  } else if (selectedElementType === "arrow") {
    selectedElement.stroke(color);
    selectedElement.fill(color);
  }

  layer.draw();
}

// Topbar text color
function applyTextColor() {
  const color = document.getElementById("textColorPicker").value;
  if (!selectedElement || !color) return;

  if (selectedElementType === "node") {
    selectedElement.find("Text").forEach((t) => {
      t.fill(color);
    });
  } else if (selectedElementType === "arrow") {
    const arrow = selectedElement;
    const arrowKey = arrow.getAttr("arrowId");
    const label = layer.findOne('Text[forArrowId="' + arrowKey + '"]');
    if (label) {
      label.fill(color);
    }
  }

  layer.draw();
}

// Topbar alignment
function setTextAlign(alignment) {
  if (!selectedElement || selectedElementType !== "node") return;
  selectedElement.find("Text").forEach((t) => {
    t.align(alignment);
  });
  layer.draw();
}

// Topbar font size
function applyFontSize() {
  const input = document.getElementById("fontSizeInput");
  const size = parseInt(input.value, 10);
  if (!selectedElement || isNaN(size) || size <= 0) return;

  if (selectedElementType === "node") {
    selectedElement.find("Text").forEach((t) => {
      t.fontSize(size);
    });
  } else if (selectedElementType === "arrow") {
    const arrow = selectedElement;
    const arrowKey = arrow.getAttr("arrowId");
    const label = layer.findOne('Text[forArrowId="' + arrowKey + '"]');
    if (label) {
      label.fontSize(size);
    }
  }

  layer.draw();
}

// Theme toggle (dark / light UI, canvas stays white)
function toggleTheme() {
  const body = document.body;
  const btn = document.getElementById("themeToggleBtn");
  if (body.classList.contains("dark-theme")) {
    body.classList.remove("dark-theme");
    body.classList.add("light-theme");
    if (btn) btn.textContent = "Dark UI";
  } else {
    body.classList.remove("light-theme");
    body.classList.add("dark-theme");
    if (btn) btn.textContent = "Light UI";
  }
}

// Serialization
function serializeDiagram() {
  return stage.toJSON();
}

function applyDiagram(jsonString) {
  const container = document.getElementById("container");
  container.innerHTML = "";

  const newStage = Konva.Node.create(jsonString, "container");
  stage = newStage;
  layer = stage.findOne("Layer");
  connections = [];
  selectedElement = null;
  selectedElementType = null;
  pendingNode = null;

  addBackgroundIfMissing();
  createTransformer();
  rebuildConnections();
}

function rebuildConnections() {
  const groups = stage.find("Group");
  groups.forEach((g) => {
    const t = g.getAttr("nodeType") || "unknown";
    registerNode(g, t);
  });

  const arrows = stage.find("Arrow");
  const labelNodes = stage.find("Text[isConnectionLabel=true]");
  const labelMap = {};

  labelNodes.forEach((lb) => {
    const forId = lb.getAttr("forArrowId");
    if (forId != null) {
      labelMap[forId] = lb;
    }
  });

  arrows.forEach((arrow) => {
    const fromId = arrow.getAttr("fromId");
    const toId = arrow.getAttr("toId");
    const arrowId = arrow.getAttr("arrowId") || null;
    if (!fromId || !toId || !arrowId) return;

    const from = stage.findOne('Group[nodeId="' + fromId + '"]');
    const to = stage.findOne('Group[nodeId="' + toId + '"]');
    if (!from || !to) return;

    const label = labelMap[arrowId];

    if (label) {
      label.listening(true);

      label.off("dblclick");
      label.off("click");
      arrow.off("dblclick");

      const editLabel = (evt) => {
        evt.cancelBubble = true;
        const current = label.text() || "";
        const updated = prompt(
          "Connection label (e.g. TTP, log ref, etc.):",
          current
        );
        if (updated !== null) {
          label.text(updated);
          layer.draw();
        }
      };

      arrow.on("dblclick", editLabel);
      label.on("dblclick", editLabel);

      label.on("click", (evt) => {
        evt.cancelBubble = true;
        clearSelectionHighlight();
        selectedElement = arrow;
        selectedElementType = "arrow";
        highlightArrow(arrow);
        layer.draw();
      });
    }

    connections.push({
      line: arrow,
      from,
      to,
      label: label || null,
    });
  });

  layer.draw();
}

// Diagram management
function newDiagram() {
  document.getElementById("container").innerHTML = "";
  connections = [];
  connecting = false;
  pendingNode = null;
  nodeCounter = 1;
  clearSelectionHighlight();
  hideContextMenu();

  initStage();
  setupStageClickHandler();
  layer.draw();
}

// Local JSON save/load
function saveLocal() {
  const json = serializeDiagram();
  const blob = new Blob([json], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const nameInput = document.getElementById("diagramName");
  const baseName = (nameInput.value || "pdrr_diagram").replace(/\s+/g, "_");

  const a = document.createElement("a");
  a.href = url;
  a.download = baseName + ".json";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

function setupLocalFileInput() {
  const input = document.getElementById("localFileInput");
  input.addEventListener("change", (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (ev) => {
      const json = ev.target.result;
      applyDiagram(json);
      setupStageClickHandler();
    };
    reader.readAsText(file);
  });
}

// Server save/load
function saveServer() {
  const json = serializeDiagram();
  const name = document.getElementById("diagramName").value || "PDRR Diagram";

  fetch("/api/save", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ name: name, diagram: json }),
  })
    .then((res) => res.json())
    .then((data) => {
      if (!data.ok) {
        alert("Save failed: " + (data.error || "unknown error"));
      } else {
        alert("Saved to server as: " + data.name);
      }
    })
    .catch((err) => {
      console.error(err);
      alert("Error saving to server");
    });
}

function loadServer() {
  fetch("/api/load")
    .then((res) => res.json())
    .then((data) => {
      if (!data.ok) {
        alert("No saved diagram found on server.");
        return;
      }
      document.getElementById("diagramName").value = data.name || "";
      applyDiagram(data.diagram);
      setupStageClickHandler();
    })
    .catch((err) => {
      console.error(err);
      alert("Error loading from server");
    });
}

// Export – the white background rect + white CSS ensure white exports
function exportJPEG() {
  const dataURL = stage.toDataURL({
    mimeType: "image/jpeg",
    quality: 0.95,
    pixelRatio: 2,
  });

  const a = document.createElement("a");
  a.href = dataURL;
  a.download = "pdrr_diagram.jpg";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

function exportPDF() {
  const { jsPDF } = window.jspdf;
  const pdf = new jsPDF("l", "pt", "a4");

  const dataURL = stage.toDataURL({
    mimeType: "image/png",
    pixelRatio: 2,
  });

  const imgProps = pdf.getImageProperties(dataURL);
  const pdfWidth = pdf.internal.pageSize.getWidth();
  const pdfHeight = (imgProps.height * pdfWidth) / imgProps.width;

  pdf.addImage(dataURL, "PNG", 0, 0, pdfWidth, pdfHeight);
  pdf.save("pdrr_diagram.pdf");
}

// Bootstrap
window.addEventListener("DOMContentLoaded", () => {
  initStage();
  setupStageClickHandler();
  setupDomContextMenuHandler();
  setupLocalFileInput();

  const menu = document.getElementById("context-menu");
  if (menu) {
    menu.addEventListener("click", (e) => {
      e.stopPropagation();
    });
  }

  window.addEventListener("keydown", (e) => {
    if (
      (e.key === "Delete" || e.key === "Backspace") &&
      selectedElement &&
      e.target.tagName !== "INPUT" &&
      e.target.tagName !== "TEXTAREA"
    ) {
      e.preventDefault();
      deleteSelected();
    }
  });

  layer.draw();
});
EOF

echo "[*] Writing Dockerfile"
cat << 'EOF' > Dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FLASK_APP=app.py
ENV FLASK_ENV=production

EXPOSE 5000

CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
EOF

echo "[*] Writing build_container.sh"
cat << 'EOF' > build_container.sh
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

if [ ! -f "static/js/konva.min.js" ] || [ ! -f "static/js/jspdf.umd.min.js" ]; then
  echo "ERROR: JS libraries missing."
  echo "They should have been downloaded by setup_pdrr_canvas.sh."
  echo "Check your network connection and rerun the setup script if needed."
  exit 1
fi

docker build -t pdrr_canvas .
EOF
chmod +x build_container.sh

echo "[*] Writing run_container.sh"
cat << 'EOF' > run_container.sh
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

docker run --rm -p 5000:5000 --name pdrr_canvas pdrr_canvas
EOF
chmod +x run_container.sh

echo "[*] Writing offline_install.sh"
cat << 'EOF' > offline_install.sh
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

IMAGE_NAME="pdrr_canvas"
TAR_FILE="pdrr_canvas.tar"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is required but not installed."
  exit 1
fi

# If image not present locally, try to load it from tar
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  if [ ! -f "$TAR_FILE" ]; then
    echo "ERROR: Docker image '$IMAGE_NAME' not present and '$TAR_FILE' not found."
    echo "Copy '$TAR_FILE' from the online build system into this directory."
    exit 1
  fi

  echo "[*] Loading Docker image from $TAR_FILE"
  docker load -i "$TAR_FILE"
fi

echo "[*] Starting container $IMAGE_NAME on port 5000"
docker run --rm -p 5000:5000 --name "$IMAGE_NAME" "$IMAGE_NAME"
EOF
chmod +x offline_install.sh

echo "[*] Writing README.txt"
cat << 'EOF' > README.txt
PDRR STORYBOARD CANVAS
======================

Overview
--------

Dockerized Flask/JavaScript app to visually build PDRR stories:

- Drag/drop Blue/Red icons, PDRR phase blocks, White Cards, labels, and text bubbles.
- Blue & Red icons include: Person, Laptop, Server, Database, plus Blue Alert / Detection.
- All text defaults to **black** (print-friendly on white canvas).
- Nodes are resizable with drag handles.
- Red connection arrows by default, connecting at edges of items.
- Connection labels start black and can be recolored.
- Connection labels editable by double-clicking arrow or label.
- Separate color palettes for shapes and text (top bar or right-click menu).
- Text alignment controls (Left/Center/Right) from top bar or right-click.
- Font size controls for ALL text (events, labels, bubbles, White Cards, connection labels).
- Delete selected nodes/arrows with Delete/Backspace or right-click → Delete.
- Large scrollable canvas for horizontal or vertical story layouts.
- **Snap-to-grid alignment** so items line up cleanly.
- **Dark / Light UI toggle**, while the canvas remains white for exports.
- Save/load JSON (local file or server-side).
- Export to JPEG and PDF for reports.
- Canvas background is **always white** for viewing, JSON loads, and exports.

White Background Guarantee
--------------------------

To make sure your diagrams are always on a white canvas, regardless of save type:

- The Konva layer contains a white background rectangle (`isBackground=true`) that:
  - Exists in every new diagram.
  - Is added if missing when loading older diagrams.
- The `<canvas>` CSS background is also set to white.
- JPEG/PDF exports render over this white background.

So:
- Local JSON save/load preserves the white background.
- Server JSON save/load preserves the white background.
- JPEG and PDF exports are rendered with a white background.

Dark / Light UI Toggle
----------------------

- The UI chrome (top bar, palette, context menu) can be toggled between **Dark UI** and **Light UI**.
- Click the **Light UI / Dark UI** button on the top bar:
  - `Light UI` button → switches from dark-theme to light-theme.
  - `Dark UI` button → switches back to dark-theme.
- The canvas itself always stays white for clarity and export consistency.

Snap-Grid Alignment
-------------------

All draggable nodes (icons, events, labels, bubbles, White Cards) are snapped to an invisible grid:

- Grid spacing: 20px.
- During drag, the node position is quantized to this grid.
- Connections are updated as nodes snap, so arrows stay aligned.

This keeps PDRR stories visually tidy and easier to read in reports.

Print-Optimized Layout
----------------------

For people who prefer to use the browser's print feature:

- When printing (`Ctrl+P` etc.), the CSS:
  - Hides the top bar, palette, and context menu.
  - Keeps a white background.
  - Expands the canvas area so the diagram is the focus.

Note: you also have built-in **Export PDF** and **Export JPEG** for more controlled outputs.

What This Setup Script Does
---------------------------

`setup_pdrr_canvas.sh` (run on an ONLINE machine):

1. Creates the `pdrr_canvas/` directory and all app files.
2. Downloads JavaScript dependencies into `static/js/`:
   - `konva.min.js`
   - `jspdf.umd.min.js`
3. Writes the Flask app, HTML template, CSS, and canvas logic.
4. Writes helper scripts:
   - `build_container.sh`  (build Docker image)
   - `run_container.sh`    (run Docker container locally)
   - `offline_install.sh`  (for airgapped/offline usage)
5. Attempts to:
   - Build the Docker image `pdrr_canvas`.
   - Export it to `pdrr_canvas.tar` for offline use.

If Docker is not installed or fails, you'll see a warning; you can later run:

  cd pdrr_canvas
  ./build_container.sh
  docker save pdrr_canvas -o pdrr_canvas.tar

Build-Time vs Run-Time Network
------------------------------

- **Build-time** (online required):
  - `setup_pdrr_canvas.sh` downloads Konva and jsPDF once.
  - Docker needs to pull `python:3.11-slim` and Python packages (Flask) once.

- **Run-time** (can be fully offline):
  - All JS and Python dependencies are baked into the Docker image.
  - The app does not call out to the internet.

Simple Offline / Airgapped Workflow
-----------------------------------

On an ONLINE machine (with Docker):

1. Run the setup script:

   chmod +x setup_pdrr_canvas.sh
   ./setup_pdrr_canvas.sh

   This:
   - Creates `pdrr_canvas/`.
   - Downloads JS libraries.
   - Builds Docker image `pdrr_canvas`.
   - Creates `pdrr_canvas.tar` in `pdrr_canvas/` (if Docker available).

2. Verify files:

   cd pdrr_canvas
   ls
   # You should see: app.py, Dockerfile, *.sh, pdrr_canvas.tar, etc.

3. Copy the entire `pdrr_canvas/` directory to the airgapped system
   (USB or other removable media).

On the AIRGAPPED machine (with Docker, no internet):

1. Copy `pdrr_canvas/` from your removable media to the offline box.

2. Run the offline installer:

   cd pdrr_canvas
   ./offline_install.sh

   This script:
   - Checks for Docker.
   - If the `pdrr_canvas` image is not present, loads it from `pdrr_canvas.tar`.
   - Starts the container, exposing port 5000.

3. Open the app in a browser on the airgapped machine:

   http://127.0.0.1:5000

Local (Online Box) Usage
------------------------

If you just want to use the app directly on the online system:

1. After running `setup_pdrr_canvas.sh`, go into the project directory:

   cd pdrr_canvas

2. If the image was not built automatically (Docker missing earlier),
   build it:

   ./build_container.sh

3. Run the app:

   ./run_container.sh

4. Browse to:

   http://127.0.0.1:5000

Palette / Icons
---------------

- **Blue Team**
  - Blue Person (head + torso figure)
  - Blue Laptop (screen + base)
  - Blue Server (rack-like tower with slots)
  - Blue Database (cylinder shape)
  - Alert / Detection (orange diamond)

- **Red Team**
  - Red Person (head + torso figure)
  - Red Laptop
  - Red Server
  - Red Database

- **PDRR Phases**
  - Prepare Event
  - Detect Event
  - Respond Event
  - Recover Event

- **White Cards**
  - White Card: white event block with "White Card" header and a body area
    to describe what the White Card represents (scope adjustment, rule change,
    inject, etc.).

- **Annotations**
  - Text Bubble (free-form narrative)
  - Plain Label (for timestamps, IDs, etc.)

Canvas Usage
------------

- Edit text:
  - Double-click any text to edit it.
  - Event blocks and White Cards: body text is editable narrative for the event.

- Style controls (top bar):
  - Shape Color → recolors shapes or arrow stroke/fill.
  - Text Color → recolors all text in a node or the arrow label.
  - Text Align → Left/Center/Right for node text.
  - Font Size → resizes all text in a node or the arrow label.
  - UI Theme → Dark UI / Light UI toggle (canvas remains white).

- Connect nodes:
  - Click **Connect Nodes**.
  - Click source node, then destination node.
  - A red arrow connects edges of the items.
  - Double-click arrow or its label to edit label text.

- Right-click context menu:
  - Right-click any node or connection (arrow/label) to open menu.
  - Menu options:
    - Delete
    - Shape Color
    - Text Color
    - Text Align (L/C/R)
    - Font Size (enter value, then **Apply**)
  - Menu stays open while you interact inside it.

- Delete:
  - Select a node or arrow and press Delete/Backspace (when not typing in an input).
  - Or right-click the item and choose **Delete**.

- Save/load:
  - **Save Local JSON** → export diagram as `.json`.
  - **Load Local JSON** → import diagram from `.json`.
  - **Save to Server** / **Load from Server**:
    - Store/restore from `data/saved_diagram.json` inside the container.

- Export:
  - **Export JPEG** → downloads `pdrr_diagram.jpg`.
  - **Export PDF**  → downloads `pdrr_diagram.pdf` (A4 landscape).

Stopping and Removal
--------------------

- Stop a running container:

  docker stop pdrr_canvas   # or Ctrl+C in the terminal running run_container.sh / offline_install.sh

- Remove the project directory on the host:

  rm -rf pdrr_canvas

- Remove the Docker image:

  docker rmi pdrr_canvas

EOF

# Try to build image and export tar automatically
echo "[*] Attempting to build Docker image and create pdrr_canvas.tar for offline use..."
if command -v docker >/dev/null 2>&1; then
  ./build_container.sh
  docker save pdrr_canvas -o pdrr_canvas.tar
  echo "[*] Docker image built and saved as pdrr_canvas.tar."
  echo "[*] For offline use, copy the entire '$PROJECT_DIR' directory to the airgapped system and run ./offline_install.sh there."
else
  echo "WARNING: Docker is not installed. Skipping image build and tar export."
  echo "Once Docker is installed, you can do:"
  echo "  cd $PROJECT_DIR"
  echo "  ./build_container.sh"
  echo "  docker save pdrr_canvas -o pdrr_canvas.tar"
fi

echo
echo "[*] Setup complete."
echo "[*] To run locally now (on this machine):"
echo "    cd $PROJECT_DIR && ./run_container.sh"
echo "[*] To use offline on another (airgapped) system:"
echo "    Copy the whole '$PROJECT_DIR' directory,"
echo "    then on the airgapped box: cd $PROJECT_DIR && ./offline_install.sh"
