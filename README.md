# Zombie Prop Hunter (GMOD Addon)

Makes `npc_zombie` target and attack nearby doors and physics props so it can work alongside destructible-door/prop addons.

## Features
- Zombies will consider doors (`prop_door_rotating`, `func_door`, `func_door_rotating`) and props (`prop_physics`, `prop_physics_multiplayer`, `func_breakable`, `func_physbox`) as valid enemies when they have no player/NPC enemy.
- Lightweight periodic scan with staggered checks to avoid performance spikes.
- ConVars for easy tuning.
  - `zm_target_props` (default `1`) – enable/disable the behavior.
  - `zm_target_props_radius` (default `900`) – scan radius.
  - `zm_target_props_debug` (default `0`) – print minimal debug info to server console.
- Plays nice with other AI/enemy targeting; if a zombie already has a live hostile enemy (e.g., a player), it will keep pursuing them.

## Install
1. Copy the `zombie_prop_hunter` folder into your server or client `garrysmod/addons/` directory.
2. Restart the game/server or `lua_refresh`.

## Console Variables (server)
```
zm_target_props 1
zm_target_props_radius 900
zm_target_props_debug 0
```

You can add these to `server.cfg`, e.g.:
```
zm_target_props 1
zm_target_props_radius 1100
```

## Notes
- This addon **does not** make doors/props destructible by itself; it only makes zombies target them. Use it with a destructible-doors/props addon of your choice.
- The zombie melee swing must be able to damage your door/prop. If your destructible addon listens for damage, it should just work once the zombie targets the entity.

## Compat
- Designed to be generic and not override base AI. It uses `AddEntityRelationship`, `SetEnemy`, and `UpdateEnemyMemory`.
- If another addon constantly overwrites enemies every tick, it may conflict (last writer wins). You can raise the scan interval to reduce contention.

## Uninstall
- Remove the addon folder or set `zm_target_props 0` and `lua_refresh`.

Licensed MIT.
