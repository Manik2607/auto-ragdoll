# Ragdoll Generator for Godot 4

A Godot Engine editor plugin that automates the creation of 3D physical ragdolls from any `Skeleton3D` node. It is designed to work best with **humanoid characters**, featuring an interactive wizard interface, automatic bone selection for rigs from **Mixamo** and **Blender**, realistic biomechanical mass distribution, and preconfigured joint limits.

---

## Features

- **Humanoid-Optimized Rig Detection**: Engineered specifically for humanoid characters. Automatically recognizes, classifies, and selects bones from standard naming structures.
- **Mixamo & Blender Support**: Automatically identifies bones from:
  - **Mixamo**: Standard prefixes and bone hierarchies (`mixamorig:Hips`, `mixamorig:LeftUpLeg`, etc.).
  - **Blender**: Standard Blender naming with `.L`/`.R` or `_L`/`_R` suffixes (e.g., `thigh.L`, `shin.L`, `upper_arm.L`), as well as Blender Rigify / metarig deformation bones (`DEF-thigh.L`, `def_arm.L`).
  - Other common formats including Character Creator (CC Base), Valve Biped, and VRM.
- **Interactive Setup Wizard**: Visual dialog interface inspired by classic ragdoll creation wizards, allowing quick inspection and manual bone slot overrides.
- **Biomechanical Mass Distribution**: Distributes total body mass realistically across body segments based on published biomechanical data (Plagenhoef et al., 1983).
- **Preconfigured Joint Constraints**: Automatically sets up `Generic6DOFJoint3D` and `HingeJoint3D` constraints with realistic angular limits for human joints (elbows, knees, spine, shoulders, hips, and neck).
- **Mirrored Collision Shapes**: Left and right limbs share collision shape resources, allowing edits to one side in the Inspector to automatically synchronize with the other.

---

## Supported Rigs

The generator works best with humanoid character skeletons. When opening the wizard, the bone matching engine parses prefixes and naming patterns to automatically populate all required slots:

| Rig Source | Example Bone Names Recognized |
| :--- | :--- |
| **Mixamo** | `mixamorig:Hips`, `mixamorig:Spine1`, `mixamorig:LeftUpLeg`, `mixamorig:LeftForeArm` |
| **Blender (Standard)** | `hips`, `spine`, `thigh.L`, `shin.L`, `foot.L`, `upper_arm.L`, `forearm.L`, `hand.L` |
| **Blender (Rigify)** | `DEF-spine`, `DEF-thigh.L`, `DEF-shin.L`, `DEF-upper_arm.L`, `DEF-forearm.L` |
| **Other Humanoid Rigs** | Biped (`bip01_`), Character Creator (`cc_base_`), VRM humanoid bones |

If a character uses non-standard or custom bone names, slots can still be selected manually using the integrated bone picker dialog.

---

## Installation

1. Copy the `addons/ragdoll_generator` directory into your Godot project's `addons/` folder:
   ```text
   your_godot_project/
   └── addons/
       └── ragdoll_generator/
           ├── plugin.cfg
           ├── ragdoll_generator.gd
           └── ragdoll_creator_dialog.gd
   ```

---

## Enabling the Plugin

1. Open your project in the **Godot Editor**.
2. From the main menu, navigate to **Project** -> **Project Settings...**.
3. Select the **Plugins** tab at the top of the dialog.
4. Locate **Ragdoll Generator** in the list of installed plugins.
5. Check the **Enable** checkbox in the status column.
6. Close the Project Settings dialog. The plugin is now active.

---

## Usage Guide

1. **Select Skeleton**: In the Scene tree, select the `Skeleton3D` node belonging to your character model.
2. **Open the Wizard**: In the 3D Viewport's top toolbar, click the **Skeleton3D** context menu and choose **Create Ragdoll**.
3. **Review Bone Assignments**: The wizard will auto-populate bone slots for Mixamo, Blender, or other recognized rigs. If any slot requires manual assignment:
   - Click the slot's picker button to open the bone search dialog.
   - Filter and select the appropriate bone from the list.
4. **Configure Parameters**:
   - **Total Mass (kg)**: Specify the total body mass (default: 70 kg). Segment masses are calculated proportionally.
   - **Joint Strength**: Adjust constraint firmness and drive parameters.
   - **Flip Forward**: Invert forward axis orientation if your character rig faces negative Z or positive Z.
5. **Generate**: Click **Create Ragdoll**. The plugin will generate the `PhysicalBone3D` hierarchy, collision shapes, and joint constraints directly under your `Skeleton3D`.

---

## Requirements

- **Godot Version**: Godot 4.0 or newer (tested with Godot 4.x Forward+ / Jolt Physics).
- **Node Type**: A character scene containing a valid `Skeleton3D` node with a humanoid bone hierarchy.

---

## Contributing

Contributions, feedback, and suggestions are welcome to help improve the plugin.

### Reporting Issues and Requesting Features

If you encounter a bug, unexpected behavior, or a rig format that fails to auto-detect correctly, opening an issue is strongly encouraged:

- **Bug Reports**: Please include your Godot version, operating system, and steps to reproduce the issue. Providing a minimal reproduction scene or sample skeleton helps diagnose problems quickly.
- **Unrecognized Rig Formats**: If you work with a humanoid rig standard or naming convention that is not automatically mapped, open an issue listing the bone naming pattern so support can be incorporated.
- **Feature Suggestions**: Ideas for workflow improvements, joint preset options, or physics adjustments are welcome.

