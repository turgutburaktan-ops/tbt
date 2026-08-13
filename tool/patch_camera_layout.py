from pathlib import Path

path = Path('lib/screens/camera_screen.dart')
text = path.read_text()

old_build = '''    return Scaffold(\n      backgroundColor: Colors.black,\n      body: SafeArea(\n        child: Column(\n          children: [\n            _buildTopBar(),\n            Expanded(child: _buildPreview()),\n            if (_aiAutoProEnabled) _buildCameraParams(),\n            _buildModes(),\n            _buildBottomControls(),\n          ],\n        ),\n      ),\n    );\n'''

new_build = '''    return Scaffold(\n      backgroundColor: Colors.black,\n      body: SafeArea(\n        child: LayoutBuilder(\n          builder: (context, constraints) {\n            const topBarHeight = 62.0;\n            const modesHeight = 54.0;\n            const controlsHeight = 112.0;\n            final paramsHeight = _aiAutoProEnabled ? 53.0 : 0.0;\n            final reservedHeight =\n                topBarHeight + modesHeight + controlsHeight + paramsHeight;\n            final maxPreviewHeight =\n                (constraints.maxHeight - reservedHeight).clamp(220.0, 2000.0);\n            final fourThreeHeight = (constraints.maxWidth - 16) * 4 / 3;\n            final previewHeight = min(fourThreeHeight, maxPreviewHeight);\n\n            return Column(\n              children: [\n                _buildTopBar(),\n                SizedBox(\n                  height: previewHeight,\n                  child: _buildPreview(),\n                ),\n                if (_aiAutoProEnabled) _buildCameraParams(),\n                Expanded(\n                  child: Container(\n                    color: const Color(0xFF050608),\n                    alignment: Alignment.bottomCenter,\n                    child: Column(\n                      mainAxisAlignment: MainAxisAlignment.end,\n                      children: [\n                        _buildModes(),\n                        _buildBottomControls(),\n                      ],\n                    ),\n                  ),\n                ),\n              ],\n            );\n          },\n        ),\n      ),\n    );\n'''

if old_build not in text:
    raise SystemExit('Camera build block not found; source changed unexpectedly')
text = text.replace(old_build, new_build, 1)

old_switch = '''          Column(\n            mainAxisSize: MainAxisSize.min,\n            children: [\n              _CircleButton(\n                icon: Icons.cameraswitch_outlined,\n                size: 54,\n                onTap: _toggleCamera,\n              ),\n              const SizedBox(height: 3),\n              Text(\n                'Flaş $_flashLabel',\n                style: const TextStyle(\n                  color: Colors.white38,\n                  fontSize: 8,\n                  fontWeight: FontWeight.w600,\n                ),\n              ),\n            ],\n          ),\n'''
new_switch = '''          _CircleButton(\n            icon: Icons.cameraswitch_outlined,\n            size: 54,\n            onTap: _toggleCamera,\n          ),\n'''
if old_switch not in text:
    raise SystemExit('Bottom camera switch block not found; source changed unexpectedly')
text = text.replace(old_switch, new_switch, 1)

path.write_text(text)
print('Camera layout patched: 4:3 preview + anchored controls')
