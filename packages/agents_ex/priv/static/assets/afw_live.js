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

    applyState(nextState) {
      this.state = nextState || { zones: [], agents: [] };

      if (!this.agentLayer) return;

      this.hudText.setText(`Aethermoor Live Map · ${this.state.agents.length} agents`);
      this.renderAgents();
    }

    renderZones() {
      this.zoneLayer.removeAll(true);

      for (const zone of this.state.zones) {
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
        node.hp.clear();
        node.hp.lineStyle(4, hpStroke(agent), 1);
        node.hp.beginPath();
        node.hp.arc(0, 0, 18, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * hpRatio(agent), false);
        node.hp.strokePath();
        node.label.setText(`${agent.label} #${agent.agent_id}`);
        node.action.setText(agent.action || "IDLE");
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

      container.add([shadow, body, hp, label, action]);
      container.setSize(190, 44);
      container.setInteractive(new window.Phaser.Geom.Circle(0, 0, 24), window.Phaser.Geom.Circle.Contains);
      container.on("pointerdown", () => {
        window.location.href = `/agents/${agent.agent_id}`;
      });

      return { container, body, hp, label, action };
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
