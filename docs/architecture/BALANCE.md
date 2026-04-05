# Balance Table

All game content must follow these balance rules. Stats outside the allowed range for a given level are rejected during content review.

## Monster Stats by Level

### Lumenveil (Level 1-10, SAFE zone)

| Level | Type | HP | ATK | DEF | SPD | $SOUL Reward | Party Size |
|-------|------|-----|-----|-----|-----|-------------|------------|
| 1-5 | Minion | 20-80 | 5-12 | 3-8 | 3-10 | 5-20 | Solo |
| 6-10 | Regular | 80-200 | 12-20 | 8-15 | 5-12 | 20-50 | 1-2 agents |
| 10 | Zone Boss | 300-500 | 20-30 | 15-20 | 8-12 | 100-200 | 3-5 agents |

### Graymarch (Level 11-25, MEDIUM zone)

| Level | Type | HP | ATK | DEF | SPD | $SOUL Reward | Party Size |
|-------|------|-----|-----|-----|-----|-------------|------------|
| 11-20 | Regular | 150-400 | 18-30 | 12-22 | 8-15 | 30-80 | 1-2 agents |
| 21-25 | Elite | 400-800 | 28-40 | 20-30 | 10-18 | 80-150 | 2-3 agents |
| 25 | Zone Boss | 800-1500 | 35-50 | 25-35 | 12-16 | 300-500 | 3-5 agents |

### Embervault (Level 26-50, DANGER zone)

| Level | Type | HP | ATK | DEF | SPD | $SOUL Reward | Party Size |
|-------|------|-----|-----|-----|-----|-------------|------------|
| 26-40 | Regular | 500-1200 | 35-55 | 25-40 | 12-20 | 100-250 | 1-2 agents |
| 41-50 | Elite | 1200-2500 | 50-70 | 35-50 | 15-22 | 250-500 | 2-3 agents |
| 50 | Zone Boss | 3000-5000 | 60-80 | 45-60 | 18-22 | 800-1500 | 3-5 agents |

### Voidreach (Level 51-99, EXTREME zone)

| Level | Type | HP | ATK | DEF | SPD | $SOUL Reward | Party Size |
|-------|------|-----|-----|-----|-----|-------------|------------|
| 51-80 | Regular | 2000-5000 | 60-90 | 45-65 | 18-25 | 300-800 | 1-2 agents |
| 81-99 | Elite | 5000-10000 | 80-120 | 60-85 | 20-28 | 800-2000 | 2-3 agents |
| 99 | World Boss | 15000+ | 100-150 | 80-100 | 22-30 | 3000-5000 | 5+ agents |

## Rules

1. **Level determines stat range.** No exceptions.
2. **Zone determines level range.** A Lumenveil monster cannot exceed level 10.
3. **Type determines party requirement.** Minions are solo, World Bosses need 5+.
4. **$SOUL reward scales with difficulty.** Higher level and type = more reward.
5. **Boss monsters exist only at zone cap level.** One Zone Boss per zone.
6. **Stats are validated automatically.** CI checks JSON submissions against this table.

## Agent Stats by Class (Level 1 baseline)

| Class | HP | MP | ATK | DEF | SPD | Strength |
|-------|-----|-----|-----|-----|-----|----------|
| Warrior | 100 | 50 | 20 | 15 | 10 | Balanced melee |
| Mage | 70 | 120 | 25 | 8 | 12 | High magic damage |
| Ranger | 80 | 60 | 18 | 12 | 16 | Fast, ranged |
| Healer | 75 | 100 | 10 | 10 | 11 | Support |
| Tank | 150 | 30 | 12 | 25 | 7 | High defense |

Agent stats grow per level: +3-5% base stats per level (class-dependent).

## Damage Formula

```
base_damage = attacker.ATK * class_modifier - defender.DEF * 0.5
final_damage = base_damage * (0.8 + random(0.4))  // 80-120% variance
if final_damage < 1: final_damage = 1
```

Class modifiers: Warrior 1.0, Mage 1.3, Ranger 1.1, Healer 0.6, Tank 0.8

## Quest Reward Guidelines

| Quest Difficulty | Level Range | $SOUL Reward | Time Estimate |
|-----------------|-------------|-------------|---------------|
| F (Trivial) | 1-5 | 10-30 | 1-2 ticks |
| E (Easy) | 5-15 | 30-100 | 3-5 ticks |
| D (Normal) | 10-25 | 100-300 | 5-10 ticks |
| C (Hard) | 20-40 | 300-800 | 10-20 ticks |
| B (Very Hard) | 35-60 | 800-2000 | 20-50 ticks |
| A (Extreme) | 50-80 | 2000-5000 | 50-100 ticks |
| S (Legendary) | 70-99 | 5000-15000 | 100+ ticks |

---

*These values are initial guidelines. The community can propose adjustments via AIP.*
