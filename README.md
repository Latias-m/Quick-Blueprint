# Quick Blueprint

A Factorio 2.0 mod that adds a Quick Blueprint button to the top-left interface.
Choose an unlocked recipe and generate an automated production-line blueprint
with machines, belts, inserters, and power poles.

[简体中文](#简体中文) | [Development and releases](#development-and-releases)

## Features

1. Select an unlocked recipe.
2. Configure the factory, modules, belt, inserter, power pole, and output direction.
3. Select an automatic machine-count target:
   - One machine
   - Output half belt or full belt
   - Highest-demand input half belt or full belt
4. Generate a ready-to-place production-line blueprint.

## Installation

Download the matching release ZIP from GitHub or the Factorio Mod Portal and
install it through Factorio's Mods menu. The current required game version is
defined in `info.json`.

## Development and releases

### Local test

Place this folder, or a ZIP named `Quick-Blueprint_<version>.zip`, in Factorio's
`mods` directory, then enable it in the in-game Mods menu.

### GitHub release

The release workflow runs when a tag in the form `v<version>` is pushed. It
checks that the tag and `info.json` have the same version, packages the mod as
`Quick-Blueprint_<version>.zip`, and creates a GitHub Release with the package.

Before releasing:

1. Update `version` in `info.json`.
2. Test the mod in Factorio.
3. Commit the change.
4. Create and push the corresponding tag:

   ```sh
   git tag v1.0.1
   git push origin main --tags
   ```

The generated ZIP contains the required top-level
`Quick-Blueprint_<version>/` directory.

## 简体中文

Quick Blueprint 在界面左上角添加快速蓝图按钮。选择一个已解锁配方后，可快速生成包含机器、传送带、机械臂和供电设施的自动化生产线蓝图。

生成前可配置工厂、模块、传送带、机械臂、电线杆、输出方向和机器数量目标。机器数量目标可选择：

- 单台机器
- 产物半条或满一条传送带
- 需求最高的原料半条或满一条传送带
