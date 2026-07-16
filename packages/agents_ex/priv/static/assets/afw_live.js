// AFW live viewer — S1 M-5: open-map camera (follow/free), minimap, region banner.
// The 512x512 placeholder world is rendered as a 1px-per-tile canvas texture
// scaled by 32 (cheap and Phaser-version-proof); S2 C-6 swaps in real tilesets.
(() => {
  const Hooks = {};
  const TILE = 32;
  const MINI = 128;

  // gid -> placeholder color, must match placeholder_tiles.png
  const PALETTE = {
    1: [106, 168, 79], // grass (Lumenveil)
    2: [94, 125, 107], // marsh (Graymarch)
    3: [140, 74, 60], // volcanic (Embervault)
    4: [74, 59, 102], // void (Voidreach)
    5: [201, 178, 133], // plaza (Havenmoor)
    6: [169, 143, 107], // road
    7: [139, 107, 71], // bridge
    8: [61, 110, 158], // water
    9: [110, 110, 110], // mountain
    10: [62, 112, 66], // forest
    11: [131, 120, 106], // rock
    12: [122, 85, 64] // building
  };

  Hooks.AethermoorPhaser = {
    mounted() {
      this.state = readState(this.el);
      this.booted = false;
      this.boot();
    },

    updated() {
      this.state = readState(this.el);

      if (this.scene) {
        this.scene.applyState(this.state);
      } else {
        this.boot();
      }
    },

    destroyed() {
      if (this.game) {
        this.game.destroy(true);
      }
    },

    boot() {
      if (this.booted) return;
      this.booted = true;

      if (!window.Phaser) {
        renderFallback(this.el, "Phaser 4 failed to load. The text dashboard remains available below.");
        return;
      }

      this.el.innerHTML = "";

      const scene = new AethermoorScene(this.state);
      this.scene = scene;

      this.game = new window.Phaser.Game({
        type: window.Phaser.AUTO,
        parent: this.el,
        width: 960,
        height: 560,
        backgroundColor: "#16120d",
        scene,
        scale: {
          mode: window.Phaser.Scale.FIT,
          autoCenter: window.Phaser.Scale.CENTER_BOTH
        }
      });
    }
  };

  class AethermoorScene extends (window.Phaser && window.Phaser.Scene ? window.Phaser.Scene : class {}) {
    constructor(initialState) {
      super("AethermoorScene");
      this.state = initialState;
      this.agentNodes = new Map();
      this.followedKey = null;
      this.activeRegionId = null;
      this.dragOrigin = null;
    }

    preload() {
      this.load.json("aethermoor-open", "/assets/maps/aethermoor_open.tmj");
    }

    create() {
      const map = this.cache.json.get("aethermoor-open");
      this.regions = regionsFromTiled(map) || this.state.zones || [];
      this.worldWidth = ((map && map.width) || 512) * TILE;
      this.worldHeight = ((map && map.height) || 512) * TILE;

      try {
        this.buildWorldTexture(map);
        this.add.image(0, 0, "afw-world").setOrigin(0, 0).setScale(TILE).setDepth(0);
      } catch (error) {
        console.error("world texture failed, falling back to region rects", error);
        this.renderRegionRects();
      }

      this.agentLayer = this.add.container(0, 0).setDepth(10);

      const cam = this.cameras.main;
      cam.setBounds(0, 0, this.worldWidth, this.worldHeight);
      cam.setZoom(0.5);
      cam.centerOn(this.worldWidth / 2, this.worldHeight / 2);

      this.createHud();
      this.createMinimap();
      this.bindCameraControls();
      this.applyState(this.state);
    }

    buildWorldTexture(map) {
      if (!map) throw new Error("open map JSON missing");

      const w = map.width;
      const h = map.height;
      const layers = {};

      for (const layer of map.layers) {
        if (layer.type === "tilelayer") layers[layer.name] = decodeLayer(layer, w * h);
      }

      const texture = this.textures.createCanvas("afw-world", w, h);
      const ctx = texture.getContext();
      const image = ctx.createImageData(w, h);

      for (let i = 0; i < w * h; i++) {
        const terrain = layers.terrain ? layers.terrain[i] : 0;
        const gid = terrain || (layers.ground ? layers.ground[i] : 0);
        const rgb = PALETTE[gid] || [22, 18, 13];
        image.data[4 * i] = rgb[0];
        image.data[4 * i + 1] = rgb[1];
        image.data[4 * i + 2] = rgb[2];
        image.data[4 * i + 3] = 255;
      }

      ctx.putImageData(image, 0, 0);
      texture.refresh();

      const filters = window.Phaser.Textures && window.Phaser.Textures.FilterMode;
      if (filters && texture.setFilter) texture.setFilter(filters.NEAREST);
    }

    renderRegionRects() {
      for (const region of this.regions) {
        const rect = this.add.rectangle(region.x, region.y, region.width, region.height, regionFill(region.danger), 0.92);
        rect.setOrigin(0, 0).setDepth(0);
        rect.setStrokeStyle(2 * TILE, 0x6d5b45, 1);

        this.add
          .text(region.x + 8 * TILE, region.y + 8 * TILE, region.name, {
            fontFamily: "Georgia, serif",
            fontSize: "160px",
            color: "#241c12",
            fontStyle: "bold"
          })
          .setDepth(1);
      }
    }

    createHud() {
      this.hudText = this.add
        .text(24, 18, "", {
          fontFamily: "Georgia, serif",
          fontSize: "20px",
          color: "#f7e8c7",
          stroke: "#1f1b16",
          strokeThickness: 3
        })
        .setScrollFactor(0)
        .setDepth(100);

      this.banner = this.add
        .text(480, 64, "", {
          fontFamily: "Georgia, serif",
          fontSize: "34px",
          color: "#f7e8c7",
          fontStyle: "bold",
          stroke: "#1f1b16",
          strokeThickness: 5
        })
        .setOrigin(0.5, 0.5)
        .setScrollFactor(0)
        .setDepth(100)
        .setAlpha(0);
    }

    createMinimap() {
      const x = 960 - MINI - 12;
      const y = 12;
      this.miniOrigin = { x, y };

      if (this.textures.exists("afw-world")) {
        const scale = MINI / (this.worldWidth / TILE);
        this.add.image(x, y, "afw-world").setOrigin(0, 0).setScale(scale).setScrollFactor(0).setDepth(90).setAlpha(0.95);
      } else {
        this.add.rectangle(x, y, MINI, MINI, 0x24201a, 0.9).setOrigin(0, 0).setScrollFactor(0).setDepth(90);
      }

      this.add
        .rectangle(x - 1, y - 1, MINI + 2, MINI + 2)
        .setOrigin(0, 0)
        .setScrollFactor(0)
        .setDepth(92)
        .setStrokeStyle(2, 0xf7e8c7, 0.9);

      this.miniDots = this.add.graphics().setScrollFactor(0).setDepth(93);
    }

    bindCameraControls() {
      const cam = this.cameras.main;

      this.input.on("pointerdown", (pointer) => {
        this.dragOrigin = { x: pointer.x, y: pointer.y, sx: cam.scrollX, sy: cam.scrollY, moved: false };
      });

      this.input.on("pointermove", (pointer) => {
        if (!pointer.isDown || !this.dragOrigin) return;

        const dx = pointer.x - this.dragOrigin.x;
        const dy = pointer.y - this.dragOrigin.y;

        if (!this.dragOrigin.moved && Math.abs(dx) + Math.abs(dy) < 8) return;

        if (!this.dragOrigin.moved) {
          this.dragOrigin.moved = true;
          this.stopFollowing();
        }

        cam.setScroll(this.dragOrigin.sx - dx / cam.zoom, this.dragOrigin.sy - dy / cam.zoom);
      });

      this.input.on("pointerup", () => {
        this.dragOrigin = null;
      });

      this.input.on("wheel", (_pointer, _objects, _dx, dy) => {
        const factor = dy > 0 ? 0.88 : 1.14;
        cam.setZoom(clamp(cam.zoom * factor, 0.06, 2));
      });

      if (this.input.keyboard) {
        this.input.keyboard.on("keydown-ESC", () => this.stopFollowing());
      }
    }

    follow(key, container) {
      this.followedKey = key;
      this.cameras.main.startFollow(container, false, 0.08, 0.08);
    }

    stopFollowing() {
      if (this.followedKey === null) return;
      this.followedKey = null;
      this.cameras.main.stopFollow();
    }

    update() {
      this.updateMinimapOverlay();
      this.updateRegionBanner();
    }

    updateMinimapOverlay() {
      if (!this.miniDots) return;

      const { x, y } = this.miniOrigin;
      const ratio = MINI / this.worldWidth;
      const cam = this.cameras.main;

      this.miniDots.clear();

      const view = cam.worldView;
      this.miniDots.lineStyle(1, 0xf7e8c7, 0.9);
      this.miniDots.strokeRect(
        x + clamp(view.x * ratio, 0, MINI),
        y + clamp(view.y * ratio, 0, MINI),
        clamp(view.width * ratio, 2, MINI),
        clamp(view.height * ratio, 2, MINI)
      );

      for (const agent of this.state.agents || []) {
        this.miniDots.fillStyle(agentFill(agent.class_id), 1);
        this.miniDots.fillRect(x + agent.x * ratio - 1, y + agent.y * ratio - 1, 3, 3);
      }
    }

    updateRegionBanner() {
      const focus = this.focusPoint();
      const region = this.regionAt(focus.x, focus.y);
      const regionId = region ? region.id : null;

      if (regionId !== this.activeRegionId) {
        this.activeRegionId = regionId;
        if (region) this.showBanner(region.name);
      }
    }

    focusPoint() {
      const followed = this.followedKey !== null && this.agentNodes.get(this.followedKey);

      if (followed) {
        return { x: followed.container.x, y: followed.container.y };
      }

      const view = this.cameras.main.worldView;
      return { x: view.centerX, y: view.centerY };
    }

    regionAt(x, y) {
      for (const region of this.regions || []) {
        if (x >= region.x && x < region.x + region.width && y >= region.y && y < region.y + region.height) {
          return region;
        }
      }

      return null;
    }

    showBanner(name) {
      if (!this.banner) return;
      this.tweens.killTweensOf(this.banner);
      this.banner.setText(name);
      this.banner.setAlpha(1);
      this.tweens.add({ targets: this.banner, alpha: 0, delay: 1400, duration: 600, ease: "Sine.easeIn" });
    }

    applyState(nextState) {
      this.state = nextState || { zones: [], agents: [] };

      if (!this.agentLayer) return;

      const mode =
        this.followedKey !== null && this.agentNodes.get(this.followedKey)
          ? `following ${followLabel(this.agentNodes.get(this.followedKey))}`
          : "free camera — drag to pan, wheel to zoom, click an agent to follow";

      this.hudText.setText(`Aethermoor · ${this.state.agents.length} agents · ${mode}`);
      this.renderAgents();
    }

    renderAgents() {
      const seen = new Set();

      for (const agent of this.state.agents) {
        const key = String(agent.agent_id);
        seen.add(key);
        let node = this.agentNodes.get(key);

        if (!node) {
          node = this.createAgentNode(agent);
          this.agentNodes.set(key, node);
          this.agentLayer.add(node.container);
        }

        node.container.setData("agent", agent);
        this.tweens.add({
          targets: node.container,
          x: agent.x,
          y: agent.y,
          duration: 450,
          ease: "Sine.easeOut"
        });

        node.body.setFillStyle(agentFill(agent.class_id), 1);
        node.body.setStrokeStyle(2, actionStroke(agent.action), 1);
        node.hp.clear();
        node.hp.lineStyle(4, hpStroke(agent), 1);
        node.hp.beginPath();
        node.hp.arc(0, 0, 18, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * hpRatio(agent), false);
        node.hp.strokePath();
        node.label.setText(`${agent.label} #${agent.agent_id}`);
        node.action.setText(`${agent.action || "IDLE"} · ${agent.zone || ""}`);
        node.speech.setText(agent.speech || "");
        node.speechBg.setVisible(Boolean(agent.speech));
        node.speech.setVisible(Boolean(agent.speech));
        sizeSpeechBubble(node);
        applyActionEffect(this, node, agent);
      }

      for (const [key, node] of this.agentNodes.entries()) {
        if (!seen.has(key)) {
          if (this.followedKey === key) this.stopFollowing();
          node.container.destroy(true);
          this.agentNodes.delete(key);
        }
      }
    }

    createAgentNode(agent) {
      const container = this.add.container(agent.x, agent.y);
      const shadow = this.add.circle(3, 5, 15, 0x000000, 0.22);
      const body = this.add.circle(0, 0, 13, agentFill(agent.class_id), 1);
      body.setStrokeStyle(2, 0x1f1b16, 1);

      const hp = this.add.graphics();
      const label = this.add.text(22, -16, "", {
        fontFamily: "Verdana, sans-serif",
        fontSize: "12px",
        color: "#f7e8c7",
        fontStyle: "bold",
        stroke: "#1f1b16",
        strokeThickness: 3
      });

      const action = this.add.text(22, 0, "", {
        fontFamily: "Verdana, sans-serif",
        fontSize: "11px",
        color: "#d9c39b",
        stroke: "#1f1b16",
        strokeThickness: 3
      });

      const speechBg = this.add.rectangle(72, -54, 160, 34, 0xfffbef, 0.92);
      speechBg.setOrigin(0.5, 0.5);
      speechBg.setStrokeStyle(1, 0x6d5b45, 0.9);
      speechBg.setVisible(false);

      const speech = this.add.text(2, -66, "", {
        fontFamily: "Georgia, serif",
        fontSize: "12px",
        color: "#2b241b",
        wordWrap: { width: 140 }
      });
      speech.setVisible(false);

      container.add([shadow, body, hp, speechBg, speech, label, action]);
      container.setSize(190, 44);
      container.setInteractive(new window.Phaser.Geom.Circle(0, 0, 24), window.Phaser.Geom.Circle.Contains);

      const key = String(agent.agent_id);
      container.on("pointerdown", (pointer) => {
        // click = camera follow (M-5); shift+click = open the agent inspector
        if (pointer.event && pointer.event.shiftKey) {
          window.location.href = `/agents/${agent.agent_id}`;
          return;
        }

        this.follow(key, container);
      });

      return { container, body, hp, label, action, speechBg, speech, lastEffect: null };
    }
  }

  function readState(el) {
    return {
      zones: readJson(el.dataset.zones, []),
      agents: readJson(el.dataset.agents, [])
    };
  }

  function readJson(value, fallback) {
    try {
      return value ? JSON.parse(value) : fallback;
    } catch (_error) {
      return fallback;
    }
  }

  function decodeLayer(layer, size) {
    if (Array.isArray(layer.data)) return layer.data;

    const bin = atob(layer.data);
    const out = new Uint32Array(size);

    for (let i = 0; i < size; i++) {
      out[i] =
        bin.charCodeAt(4 * i) |
        (bin.charCodeAt(4 * i + 1) << 8) |
        (bin.charCodeAt(4 * i + 2) << 16) |
        (bin.charCodeAt(4 * i + 3) << 24);
    }

    return out;
  }

  function regionsFromTiled(map) {
    const layer = map && map.layers && map.layers.find((l) => l.name === "regions" && Array.isArray(l.objects));
    if (!layer) return null;

    return layer.objects.map((object) => ({
      id: tiledProperty(object, "regionId") || object.id,
      name: object.name,
      danger: object.type,
      x: object.x,
      y: object.y,
      width: object.width,
      height: object.height
    }));
  }

  function tiledProperty(object, name) {
    const property = object.properties && object.properties.find((entry) => entry.name === name);
    return property ? property.value : undefined;
  }

  function followLabel(node) {
    const agent = node.container.getData("agent");
    return agent ? `${agent.label} #${agent.agent_id}` : "agent";
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function renderFallback(el, message) {
    el.innerHTML = `<div style="padding:16px;border-radius:14px;background:#fff2dc;border:1px solid #e8bb6b;">${message}</div>`;
  }

  function regionFill(danger) {
    switch (danger) {
      case "HUB":
        return 0xe8d9ae;
      case "SAFE":
        return 0xdff0d0;
      case "MEDIUM":
        return 0xeee0aa;
      case "DANGER":
        return 0xedc18f;
      case "EXTREME":
        return 0xd3b4c6;
      default:
        return 0xe7dcc8;
    }
  }

  function agentFill(classId) {
    switch (classId) {
      case 1:
        return 0xd95f43;
      case 2:
        return 0x4779d4;
      case 3:
        return 0x4f9f63;
      case 4:
        return 0xd4a53e;
      case 5:
        return 0x8a6db1;
      default:
        return 0x6f6251;
    }
  }

  function actionStroke(action) {
    switch (action) {
      case "FIGHT":
        return 0xffd166;
      case "REST":
        return 0xa7e3a1;
      case "TRADE":
        return 0x8fd3ff;
      case "TALK":
        return 0xfff3a3;
      case "EXPLORE":
        return 0xd4b483;
      default:
        return 0x1f1b16;
    }
  }

  function applyActionEffect(scene, node, agent) {
    const action = agent.action || "IDLE";
    if (node.lastEffect === `${action}:${agent.tick}`) return;
    node.lastEffect = `${action}:${agent.tick}`;

    scene.tweens.killTweensOf([node.body, node.speechBg]);
    node.container.setScale(1);
    node.body.setAlpha(1);
    node.speechBg.setAlpha(0.92);

    switch (action) {
      case "FIGHT":
        scene.tweens.add({
          targets: node.container,
          scale: 1.18,
          duration: 140,
          yoyo: true,
          repeat: 2,
          ease: "Back.easeOut"
        });
        break;
      case "REST":
        scene.tweens.add({
          targets: node.body,
          alpha: 0.55,
          duration: 900,
          yoyo: true,
          repeat: 1,
          ease: "Sine.easeInOut"
        });
        break;
      case "TRADE":
        scene.tweens.add({
          targets: node.container,
          angle: 6,
          duration: 180,
          yoyo: true,
          repeat: 2,
          ease: "Sine.easeInOut"
        });
        break;
      case "TALK":
        scene.tweens.add({
          targets: node.speechBg,
          alpha: 0.55,
          duration: 420,
          yoyo: true,
          repeat: 2,
          ease: "Sine.easeInOut"
        });
        break;
      default:
        break;
    }
  }

  function sizeSpeechBubble(node) {
    if (!node.speech.visible) return;
    const bounds = node.speech.getBounds();
    node.speechBg.setSize(Math.max(bounds.width + 24, 90), Math.max(bounds.height + 16, 30));
    node.speechBg.setPosition(
      bounds.x - node.container.x + bounds.width / 2,
      bounds.y - node.container.y + bounds.height / 2
    );
  }

  function hpStroke(agent) {
    const ratio = hpRatio(agent);
    if (ratio <= 0.35) return 0xbd2d2d;
    if (ratio <= 0.7) return 0xc9892b;
    return 0x2f8f46;
  }

  function hpRatio(agent) {
    const maxHp = Math.max(agent.max_hp || 1, 1);
    return Math.max(0, Math.min(1, (agent.hp || 0) / maxHp));
  }

  function bootLiveView() {
    if (!window.Phoenix || !window.LiveView) {
      console.error("Phoenix LiveView client libraries are not available.");
      return;
    }

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
    const liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
      hooks: Hooks,
      params: { _csrf_token: csrfToken }
    });

    liveSocket.connect();
    window.liveSocket = liveSocket;
  }

  window.addEventListener("DOMContentLoaded", bootLiveView);
})();
