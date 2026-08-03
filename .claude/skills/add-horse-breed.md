# 新增马匹品种

为"牛仔跑酷"项目添加一匹新马。

## 触发条件

用户说"加一匹马"、"新增品种"、"添加新马"等。

## 需要用户提供的信息

| 字段 | 说明 | 示例 |
|------|------|------|
| 中文名 | 马匹显示名称 | 白蹄乌 |
| 英文前缀 | 文件命名用，小写无空格 | baitiwu |
| 速度 | base_speed | 50 |
| 耐力 | base_stamina | 25 |
| 性格范围 | personality_min / personality_max | 30~100 |
| 脾气范围 | temper_min / temper_max | 30~100 |
| 顺从度下限 | obedience_min | 30 |
| 稀有度 | 0=常见 1=稀有 2=史诗 3=传说 | 1 |
| 售价 | 金币 | 200 |
| 颜色 | Color(r,g,b,a) | Color(0.1,0.1,0.1,1) |
| 美术 zip | run/exhausted/crazy 三个 zip 的路径 | — |

如果用户未提供售价，根据稀有度和属性自动估算。

## 步骤

### 1. 创建 `.tres` 品种文件

路径：`resources/breeds/<英文前缀>.tres`

```gdscript
[gd_resource type="Resource" script_class="HorseBreed" load_steps=2 format=3 uid="uid://breed_<前缀>"]

[ext_resource type="Script" path="res://scripts/resources/horse_breed.gd" id="1_breed"]

[resource]
script = ExtResource("1_breed")
breed_name = "<中文名>"
base_speed = <速度>
base_stamina = <耐力>
personality_min = <性格min>
personality_max = <性格max>
temper_min = <脾气min>
temper_max = <脾气max>
obedience_min = <顺从度>
rarity = <稀有度>
spawn_weight = 15.0
color = <颜色>
```

注意 `uid` 格式为 `uid://breed_<前缀>`。

### 2. 注册到 4 个脚本（共 6 处）

| 文件 | 位置 | 添加内容 |
|------|------|----------|
| `scripts/game/game_scene.gd` | `BREED_PATHS` 数组末尾 | `"res://resources/breeds/<前缀>.tres"` |
| `scripts/game/game_scene.gd` | `_build_sprite_frames_cache()` 的 `breeds` 数组 | `"<前缀>"` |
| `scripts/game/horse.gd` | `BREED_FILE_MAP` 字典 | `"<中文名>": "<前缀>"` |
| `scripts/scenes/horse_select.gd` | `BREED_FILE_MAP` 字典 | `"<中文名>": "<前缀>"` |
| `scripts/scenes/stable_menu.gd` | `BREED_FILE_MAP` 字典 | `"<中文名>": "<前缀>"` |
| `scripts/scenes/stable_menu.gd` | `BREED_BASE_PRICE` 字典 | `"<中文名>": <售价>` |

所有编辑使用 Python 脚本执行（处理 tab 缩进），不使用 Edit 工具（避免 tab 匹配问题）。

### 3. 处理美术资源

美术资源为三个 zip 文件，位于：
- `Art_Resource/Horses/<前缀>_run/<前缀>_run.zip`
- `Art_Resource/Horses/<前缀>_exhausted/<前缀>_exhausted.zip`
- `Art_Resource/Horses/<前缀>_crazy/<前缀>_crazy.zip`

每个 zip 内为帧序列 PNG，解压到 `frames/` 子目录后重命名为 `1.png, 2.png, 3.png...`：

```bash
cd "Art_Resource/Horses"
for d in <前缀>_run <前缀>_exhausted <前缀>_crazy; do
  mkdir -p "$d/frames"
  unzip -o "$d/${d}.zip" -d "$d/frames/"
  prefix="${d}_"
  for f in "$d/frames/${prefix}"*.png; do
    newname=$(basename "$f" | sed "s/^${prefix}//")
    mv "$f" "$d/frames/$newname"
  done
done
```

### 4. 验证

```bash
grep -rn "<前缀>\|<中文名>" scripts/ resources/breeds/
```

确认 6 处注册 + 1 个 .tres = 至少 7 处引用。

## 不需要改的文件

- `horse_breed.gd` / `horse_data.gd` — 字段已覆盖所有需求
- `player.gd` / `game_manager.gd` — 驯服检查通用
- `save_system.gd` — 通过 resource_path 动态加载

## 已知品种参考

| 名 | 前缀 | 稀有 | 速度 | 耐力 | 性格 | 脾气 | 顺从 | 售价 |
|----|------|------|------|------|------|------|------|------|
| 蒙古马 | mongolian | 常见 | 40 | 20 | 20-80 | 20-80 | 0 | 10 |
| 伊犁马 | yili | 稀有 | 55 | 15 | 20-40 | 20-50 | 30 | 50 |
| 纯血马 | thoroughbred | 史诗 | 72 | 15 | 60-90 | 50-90 | 50 | 100 |
| 汗血宝马 | ferghana | 传说 | 65 | 30 | 80-100 | 80-100 | 70 | 500 |
| 赤兔马 | chitu | 传说 | 100 | 30 | 90-100 | 0-10 | 99 | 500 |
| 绝影 | jueying | 史诗 | 80 | 15 | 0-40 | 0-40 | 50 | 100 |
| 白蹄乌 | baitiwu | 稀有 | 50 | 25 | 30-100 | 30-100 | 30 | 200 |
