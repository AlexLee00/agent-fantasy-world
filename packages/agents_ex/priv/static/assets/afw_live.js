(() => {
  const Hooks = {};

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
    }

    create() {
      this.cameras.main.setBackgroundColor("#16120d");
      this.mapZones = zonesFromTiled(this.cache.json.get("aethermoor-overview")) || this.state.zones;
      this.zoneLayer = this.add.container(0, 0);
      this.agentLayer = this.add.container(0, 0);
      this.hudText = this.add.text(24, 18, "", {
        fontFamily: "Georgia, serif",
        fontSize: "22px",
        color: "#f7e8c7"
      });

      this.renderZones();
      this.applyState(this.state);
    }

    preload() {
      this.load.json("aethermoor-overview", "/assets/maps/aethermoor_overview.tmj");
    }

    applyState(nextState) {
      this.state = nextState || { zones: [], agents: [] };

      if (!this.agentLayer) return;

      this.hudText.setText(`Aethermoor Live Map · ${this.state.agents.length} agents`);
      this.renderAgents();
    }

    renderZones() {
      this.zoneLayer.removeAll(true);

      for (const zone of this.mapZones || this.state.zones) {
        const fill = zoneFill(zone.danger);
        const rect = this.add.rectangle(zone.x, zone.y, zone.width, zone.height, fill, 0.92);
        rect.setOrigin(0, 0);
        rect.setStrokeStyle(2, 0x6d5b45, 1);

        const label = this.add.text(zone.x + 18, zone.y + 18, zone.name, {
          fontFamily: "Georgia, serif",
          fontSize: "21px",
          color: "#241c12",
          fontStyle: "bold"
        });

        const danger = this.add.text(zone.x + 18, zone.y + 46, zone.danger, {
          fontFamily: "Verdana, sans-serif",
          fontSize: "12px",
          color: "#4f3c2b"
        });

        this.zoneLayer.add([rect, label, danger]);
      }
    }

    renderAgents() {
      const seen = new Set();

      for (const agent of this.state.agents) {
        seen.add(String(agent.agent_id));
        const key = String(agent.agent_id);
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
        node.action.setText(agent.action || "IDLE");
        node.speech.setText(agent.speech || "");
        node.speechBg.setVisible(Boolean(agent.speech));
        node.speech.setVisible(Boolean(agent.speech));
        sizeSpeechBubble(node);
        applyActionEffect(this, node, agent);
      }

      for (const [key, node] of this.agentNodes.entries()) {
        if (!seen.has(key)) {
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
      container.on("pointerdown", () => {
        window.location.href = `/agents/${agent.agent_id}`;
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

  function zonesFromTiled(map) {
    const zoneLayer = map?.layers?.find((layer) => layer.name === "zones" && Array.isArray(layer.objects));
    if (!zoneLayer) return null;

    return zoneLayer.objects.map((object) => ({
      id: tiledProperty(object, "zoneId") || object.id,
      name: object.name,
      danger: object.type,
      x: object.x,
      y: object.y,
      width: object.width,
      height: object.height
    }));
  }

  function tiledProperty(object, name) {
    const property = object.properties?.find((entry) => entry.name === name);
    return property?.value;
  }

  function renderFallback(el, message) {
    el.innerHTML = `<div style="padding:16px;border-radius:14px;background:#fff2dc;border:1px solid #e8bb6b;">${message}</div>`;
  }

  function zoneFill(danger) {
    switch (danger) {
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

    scene.tweens.killTweensOf([node.container, node.body, node.speechBg]);
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
      case "EXPLORE":
        scene.tweens.add({
          targets: node.container,
          y: node.container.y - 4,
          duration: 300,
          yoyo: true,
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
    node.speechBg.setPosition(bounds.x - node.container.x + bounds.width / 2, bounds.y - node.container.y + bounds.height / 2);
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
