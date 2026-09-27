from pathlib import Path

path = Path('lib/screens/camera_screen.dart')
text = path.read_text()

old_build = '''    return Scaffold(\n      backgroundColor: Colors.black,\n      body: SafeArea(\n        child: Column(\n          children: [\n            _buildTopBar(),\n            Expanded(child: _buildPreview()),\n            if (_aiAutoProEnabled) _buildCameraParams(),\n            _buildModes(),\n            _buildBottomControls(),\n          ],\n        ),\n      ),\n    );\n'''

new_build = '''    return Scaffold(\n      backgroundColor: Colors.black,\n      body: SafeArea(\n        child: LayoutBuilder(\n          builder: (context, constraints) {\n            const paramsHeight = 48.0;\n            const modesHeight = 54.0;\n            const controlsHeight = 112.0;\n            final previewHeight = (constraints.maxHeight -\n                    paramsHeight -\n                    modesHeight -\n                    controlsHeight)\n                .clamp(320.0, constraints.maxHeight);\n\n            return Column(\n              children: [\n                SizedBox(\n                  height: previewHeight,\n                  child: Stack(\n                    children: [\n                      Positioned.fill(child: _buildPreview()),\n                      Positioned(\n                        top: 2,\n                        left: 0,\n                        right: 0,\n                        child: _buildTopBar(),\n                      ),\n                    ],\n                  ),\n                ),\n                _buildCameraParams(),\n                _buildModes(),\n                _buildBottomControls(),\n              ],\n            );\n          },\n        ),\n      ),\n    );\n'''

if old_build not in text:
    # Support already-patched builds from an earlier workflow revision.
    start = text.find('    return Scaffold(\n      backgroundColor: Colors.black,\n      body: SafeArea(\n        child: LayoutBuilder(')
    end_marker = '    );\n  }\n\n  Widget _buildTopBar()'
    end = text.find(end_marker, start)
    if start < 0 or end < 0:
        raise SystemExit('Camera build block not found; source changed unexpectedly')
    text = text[:start] + new_build + text[end + len('    );\n  }\n'):]
else:
    text = text.replace(old_build, new_build, 1)

# Keep the top bar compact because it now overlays the preview.
text = text.replace(
    '''  Widget _buildTopBar() {\n    return SizedBox(\n      height: 62,\n''',
    '''  Widget _buildTopBar() {\n    return SizedBox(\n      height: 56,\n''',
    1,
)

# Parameters are always visible so there is no dead black zone and users can
# verify the actual ISO/shutter/EV profile even when AI AUTO PRO is off.
text = text.replace(
    '''  Widget _buildCameraParams() {\n    return Container(\n      height: 48,\n      margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),\n''',
    '''  Widget _buildCameraParams() {\n    return Container(\n      height: 48,\n      margin: EdgeInsets.zero,\n''',
    1,
)

# The old bottom label could be mistaken for the camera-switch action.
old_switch = '''          Column(\n            mainAxisSize: MainAxisSize.min,\n            children: [\n              _CircleButton(\n                icon: Icons.cameraswitch_outlined,\n                size: 54,\n                onTap: _toggleCamera,\n              ),\n              const SizedBox(height: 3),\n              Text(\n                'Flaş $_flashLabel',\n                style: const TextStyle(\n                  color: Colors.white38,\n                  fontSize: 8,\n                  fontWeight: FontWeight.w600,\n                ),\n              ),\n            ],\n          ),\n'''
new_switch = '''          _CircleButton(\n            icon: Icons.cameraswitch_outlined,\n            size: 54,\n            onTap: _toggleCamera,\n          ),\n'''
if old_switch in text:
    text = text.replace(old_switch, new_switch, 1)

path.write_text(text)
print('Camera layout patched: bounded preview + overlay top bar + no spacer')
