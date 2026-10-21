package funkin.states.options;

import funkin.states.options.Option;

class MobileOptionsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Mobile Options';
		rpcTitle = 'Mobile Options Menu';
		
		var option:Option = new Option('Invisible Hitbox', 'If checked, the hitbox lanes stay invisible while you play,\nbut they still work.', 'invisibleHitbox', BOOL, false);
		addOption(option);
		
		var option:Option = new Option('Invisible Pause Button', 'If checked, the pause button is hidden during songs,\nbut tapping its corner still pauses.', 'invisiblePauseButton', BOOL, false);
		addOption(option);
		
		super();
	}
}
