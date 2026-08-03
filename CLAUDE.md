# 牛仔狂奔 (Cowboy is CRAZY) — Godot 4.7 项目

## 技术栈

- Godot 4.7 (Mobile 渲染器, D3D12)
- GDScript
- 像素风 2D 横向卷轴

## 项目结构
```
新建游戏项目/
├── scenes/                    场景文件
│   ├── main_menu.tscn         主页
│   ├── game_scene.tscn        核心游戏场景
│   ├── horse_select.tscn      选马界面
│   ├── stable_menu.tscn       马厩管理
│   └── settings_menu.tscn     设置
├── scripts/
│   ├── autoload/              Autoload
│   │   ├── game_manager.gd    全局状态（金币/马厩/骑乘记录）
│   │   ├── save_system.gd     存档（ConfigFile → user://save.dat）
│   │   └── audio_manager.gd   音频
│   ├── game/
│   │   ├── game_scene.gd      主逻辑（生成/相机/碰撞）
│   │   ├── player.gd          骑手（移动/跳跃/换马/动画）
│   │   ├── horse.gd           马（体力/狂暴/动画）
│   │   ├── camera_controller.gd
│   │   └── ui/
│   │       ├── game_hud.gd    距离/体力条/马名
│   │       └── game_over_panel.gd  结算（收入马厩流程）
│   ├── resources/
│   │   ├── horse_breed.gd     HorseBreed 资源类
│   │   └── horse_data.gd      HorseData 资源类
│   └── scenes/
│       ├── main_menu.gd
│       ├── horse_select.gd
│       ├── stable_menu.gd
│       └── settings_menu.gd
├── resources/breeds/          4个品种 .tres
│   ├── mongolian.tres         蒙古马(common)
│   ├── yili.tres              伊犁马(rare)
│   ├── thoroughbred.tres      纯血马(epic)
│   └── ferghana.tres          汗血宝马(legendary)
├── Art_Resource/              美术资源（PNG Sprite Sheets）
│   ├── Horses/                12张（4品种x3动画）
│   ├── Rider/                 3张
│   ├── Background/            2张
│   └── Obstacles/             2张
└── generate_pixel_art.py      像素画占位生成脚本
```

## Autoload

1. SaveSystem — `res://scripts/autoload/save_system.gd`
2. GameManager — `res://scripts/autoload/game_manager.gd`
3. AudioManager — `res://scripts/autoload/audio_manager.gd`

GameManager._ready() 调用 SaveSystem.load_game()，无存档时初始化首马"小蒙古"。

## 游戏流程

MainMenu → HorseSelect → GameScene → GameOver → MainMenu/GameScene

## 关键尺寸

| 对象 | 尺寸 |
|------|------|
| 马精灵 | 120x80 px (4帧水平) |
| 骑手精灵 | 60x100 px |
| 骑手碰撞体 | 60x120 |
| 骑乘偏移 | (0, -100) |
| 墙壁 | 80px厚 |
| 障碍物 | 60x60 |

## 关键信号

- player.landed_on_horse(horse) — 骑上马
- player.player_fell — 落马 → game over
- horse.exhausted — 力竭 → game over
- horse.died — 骑手弹起

## 重要注意事项

1. 骑马时骑手碰撞体必须 disabled（mount()中设为true），否则挡住马向上移动
2. 体力在 mount() 时通过 horse.reset_stamina_timer() 回满
3. 边界判定用 player.on_horse.global_position.y（马的位置），不是骑手位置
4. SpriteFrames 运行时从 PNG Sprite Sheet 动态创建（AtlasTexture.region）
5. horse.gd 中 BREED_FILE_MAP 映射中文品种名到文件前缀
