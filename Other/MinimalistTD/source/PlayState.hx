package;

import flash.display.Sprite;
import openfl.Assets;
import flash.display.BitmapData;
import flash.display.BlendMode;
import flash.display.Graphics;
import flash.geom.Rectangle;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.group.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tile.FlxTilemap;
import flixel.tweens.FlxTween;
import flixel.tweens.misc.VarTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxMath;
import flixel.util.FlxPoint;
import flixel.util.FlxSpriteUtil;

class PlayState extends FlxState
{
	// Public variables
	public var enemiesToKill:Int = 0;
	public var enemiesToSpawn:Int = 0;
	public var towerPrice:Int = 8;
	public var wave:Int = 0;
	
	// Public groups
	public var bulletGroup:FlxTypedGroup<Bullet>;
	public var emitterGroup:FlxTypedGroup<EnemyGibs>;
	public var enemyGroup:FlxTypedGroup<Enemy>;
	public var towerIndicators:FlxTypedGroup<FlxSprite>;
	
	// Groups
	private var _guiGroup:FlxGroup;
	private var _lifeGroup:FlxGroup;
	private var _topGui:FlxGroup;
	private var _towerGroup:FlxTypedGroup<Tower>;
	private var _upgradeMenu:FlxGroup;
	
	// Sprites
	private var _buildHelper:FlxSprite;
	private var _goal:FlxSprite;
	private var _towerRange:FlxSprite;
	
	// Texts
	private var _centerText:FlxText;
	private var _enemyText:FlxText;
    private var _moneyText:FlxText;
	private var _tutText:FlxText;
	private var _waveText:FlxText;
	
	// Buttons
	private var _damageButton:Button;
	private var _firerateButton:Button;
	private var _nextWaveButton:Button;
	private var _rangeButton:Button;
	private var _speedButton:Button;
	private var _towerButton:Button;
	
	// Other objects
	private var _map:FlxTilemap;
	private var _towerSelected:Tower;
	
	// Private variables
	
	private var _buildingMode:Bool = false;
	private var _gameOver:Bool = false;
	private var _lives:Int = 9;
	private var _money:Int = 50;
	private var _spawnCounter:Int = 0;
	private var _spawnInterval:Int = 1;
	private var _speed:Int = 1;
	private var _upgradeHasBeenBought:Bool = false;
	private var _waveCounter:Int = 0;
	
	private var _enemySpawnX:Int = 28;
	private var _enemySpawnY:Int = -20;
	private var _goalX:Int = 245;
	private var _goalY:Int = 43;
	
	/**
	 * Helper BitmapData object to draw tower's range graphic
	 */
	private static var RANGE_BITMAP:BitmapData = null;
	/**
	 * Helper Rectangle object for faster tower's range graphic drawing
	 */
	private static var STAGE_RECTANGLE:Rectangle = new Rectangle();
	/**
	 * Helper FlxPoint object for less garbage creation
	 */
	private static var HELPER_POINT:FlxPoint = new FlxPoint();
	
	#if debug
	inline private static var MONEY_CHEAT:Bool = true;
	#end
	
	/**
	 * Create a new playable game state.
	 */
	override public function create():Void
	{
		Reg.PS = this;
		
		#if !js
		FlxG.sound.playMusic( "td2" );
		#end
		
		FlxG.timeScale = 1;
		
		// Create map
		
		_map = new FlxTilemap();
		_map.loadMap( Assets.getText( "tilemaps/play_tilemap.csv" ), Reg.tileImage );
		
		bulletGroup = new FlxTypedGroup<Bullet>();
		emitterGroup = new FlxTypedGroup<EnemyGibs>();
		enemyGroup = new FlxTypedGroup<Enemy>();
		_towerGroup = new FlxTypedGroup<Tower>();
		towerIndicators = new FlxTypedGroup<FlxSprite>();
		
		// Set up bottom GUI
		
		var guiUnderlay:FlxSprite = new FlxSprite( 0, FlxG.height - 16 );
		guiUnderlay.makeGraphic( FlxG.width, 16, FlxColor.WHITE );
		
		_guiGroup = new FlxGroup();
		
		var height:Int = FlxG.height - 18;
		_towerButton = new Button( 2, height, "Buy [T]ower ($" + towerPrice + ")", buildTowerCallback );
		_nextWaveButton = new Button( 120, height, "[N]ext Wave", nextWaveCallback, [ false ], 143 );
		_speedButton = new Button( FlxG.width - 20, height, "x1", speedButtonCallback, null, 21 );
		
		_tutText = new FlxText( _nextWaveButton.x, _nextWaveButton.y + 3, FlxG.width, "Click on a Tower to Upgrade it!" );
		_tutText.visible = false;
		_tutText.color = FlxColor.BLACK;
		
		_guiGroup.add( _towerButton );
		_guiGroup.add( _nextWaveButton );
		_guiGroup.add( _speedButton );
		_guiGroup.add( _tutText );
		
		// End GUI setup
		
		// Set up upgrade menu, hidden initially, also part of bottom GUI
		
		_upgradeMenu = new FlxGroup();
		
		_rangeButton = new Button( 14, height, "Range (##): $##", upgradeRangeCallback );
		_damageButton = new Button( 100, height, "Damage (##): $##", upgradeDamageCallback );
		_firerateButton = new Button( 200, height, "Firerate (##): $##", upgradeFirerateCallback );
		
		_upgradeMenu.add( new Button( 2, height, "<", toggleUpgradeMenu, [false], 10 ) );
		_upgradeMenu.add( _rangeButton );
		_upgradeMenu.add( _damageButton );
		_upgradeMenu.add( _firerateButton );
		
		_upgradeMenu.visible = false;
		
		// End upgrade setup
		
		// Set up top GUI
		
		_topGui = new FlxGroup();
		
		_moneyText = new FlxText( 0, 2, FlxG.width - 4, "$: " + money );
		_moneyText.alignment = "right";
		
		_enemyText = new FlxText( 120, 2, FlxG.width, "Wave" );
		_enemyText.visible = false;
		
		_waveText = new FlxText( 222, 2, FlxG.width, "Wave" );
		_waveText.visible = false;
		
		_topGui.add( _moneyText );
		_topGui.add( _enemyText );
		_topGui.add( _waveText );
		
		// Set up goal
		
		_goal = new FlxSprite( _goalX, _goalY, "images/goal.png" );
		
		_lifeGroup = new FlxGroup();
		
		for ( xPos in 0...3 ) {
			for ( yPos in 0...3 ) {
				var life:FlxSprite = new FlxSprite( _goal.x + 5 + 4 * xPos, _goal.y + 5 + 4 * yPos );
				life.makeGraphic( 2, 2, FlxColor.WHITE );
				_lifeGroup.add( life );
			}
		}
		
		// End goal setup
		
		// Set up miscellaneous items: center text, buildhelper, and the tower range image
		
		_centerText = new FlxText( -200, FlxG.height / 2 - 20, FlxG.width, "", 16 );
		_centerText.alignment = "center";
		_centerText.borderStyle = FlxText.BORDER_SHADOW;
		_centerText.blend = BlendMode.INVERT;
		
		_buildHelper = new FlxSprite( 0, 0, "images/checker.png" );
		_buildHelper.visible = false;
		
		_towerRange = new FlxSprite( 0, 0 );
		_towerRange.visible = false;
		
		// End miscellaneous set up
		
		// Add everything to the state
		
		add( _map );
		add( bulletGroup );
		add( emitterGroup );
		add( enemyGroup );
		add( _towerRange );
		add( _towerGroup );
		add( towerIndicators );
		add( _goal );
		add( _lifeGroup );
		add( _buildHelper );
		add( guiUnderlay );
		add( _guiGroup );
		add( _upgradeMenu );
		add( _topGui );	
		add( _centerText );
		
		// Call this to set up for first wave
		
		killedWave();
	}
	
	/**
	 * Called before each wave to set up _waveCounter and some UI elements.
	 */
	public function killedWave():Void
	{
		if ( wave != 0 ) {
			#if !js
			FlxG.sound.play( "wavedefeated" );
			#end
		}
		
		_waveCounter = 3 * FlxG.framerate;
		
		_nextWaveButton.visible = true;
		_tutText.visible = false;
		_enemyText.visible = false;
	}
	
	override public function update():Void
	{
		// Update enemies left indicator
		
		_enemyText.text = "Enemies left: " + enemiesToKill;
		
		// These elements expand when increased; this reduces their size back to normal
		
		if ( _moneyText.size > 8 ) {
			_moneyText.size--;
		}
		
		if ( _enemyText.size > 8 ) {
			_enemyText.size--;
		}
		
		if ( _waveText.size > 8 ) {
			_waveText.size--;
		}
		
		// Check for key presses, which can substitute for button clicks.
		
		#if !mobile
		if ( FlxG.keys.justReleased.T ) buildTowerCallback( true ); 
		if ( FlxG.keys.justReleased.SPACE ) speedButtonCallback( true ); 
		if ( FlxG.keys.justReleased.R ) FlxG.resetState(); 
		if ( FlxG.keys.justReleased.N ) nextWaveCallback( true ); 
		if ( FlxG.keys.justReleased.ESCAPE ) escapeBuilding(); 
		if ( FlxG.keys.justReleased.ONE ) upgradeRangeCallback(); 
		if ( FlxG.keys.justReleased.TWO ) upgradeDamageCallback(); 
		if ( FlxG.keys.justReleased.THREE ) upgradeFirerateCallback(); 
		#end
		
		// If needed, updates the grid highlight square buildHelper and the range indicator
		
		if ( _buildingMode ) {
			_buildHelper.x = FlxG.mouse.x - ( FlxG.mouse.x % 8 );
			_buildHelper.y = FlxG.mouse.y - ( FlxG.mouse.y % 8 );
			updateRangeSprite( _buildHelper.getMidpoint(), 40 );
		}
		
		// Controls mouse clicks, which either build a tower or offer the option to upgrade a tower.
		
		if ( FlxG.mouse.justReleased ) {
			if ( _buildingMode ) {
				buildTower();
			} else {
				#if !mobile
				// If the user clicked on a tower, they get the upgrade menu
				for ( tower in _towerGroup.members ) {
					if ( FlxMath.pointInCoordinates( Std.int(FlxG.mouse.x), Std.int(FlxG.mouse.y), Std.int(tower.x), Std.int(tower.y), Std.int(tower.width), Std.int(tower.height))) {
						_towerSelected = tower;
						toggleUpgradeMenu( true );
						break; // We've found the selected tower, can stop cycling through them
					} else if ( FlxG.mouse.y < FlxG.height - 20 ) {
						toggleUpgradeMenu( false );
					}
				}
				#else
				// If the user tapped NEAR a tower, they get the upgrade menu.
				var nearestTower:Tower = getNearestTower( FlxG.mouse.x, FlxG.mouse.y, 20 );
				if ( nearestTower != null ) {
					_towerSelected = nearestTower;
					toggleUpgradeMenu( true );
				} else if ( FlxG.mouse.y < FlxG.height - 20 ) {
					toggleUpgradeMenu(false);
				}
				#end
			}
		}
		
		// If an enemy hits the goal, it will lose life and the enemy explodes
		
		FlxG.overlap( enemyGroup, _goal, hitGoal );
		
		// If a bullet hits an enemy, it will lose health
		
		FlxG.overlap( bulletGroup, enemyGroup, hitEnemy );
		
		// Controls wave spawning, enemy spawning, 
		
		if ( enemiesToKill == 0 && _towerGroup.length > 0 ) {
			_waveCounter -= Std.int( FlxG.timeScale );
			_nextWaveButton.text = "[N]ext Wave in " + Math.ceil( _waveCounter / FlxG.framerate );
			
			if ( _waveCounter <= 0 ) {
				spawnWave();
			}
		} else {
			_spawnCounter += Std.int( FlxG.timeScale );
			
			if ( _spawnCounter > _spawnInterval * FlxG.framerate && enemiesToSpawn > 0 ) {
				spawnEnemy();
			}
		}
		
		super.update();
	} // End update
	
	#if mobile
	/**
	 * Used to get the nearest tower within a particular search radius. Makes selecting towers easier for touch screens.
	 * 
	 * @param	X				The X position of the screen touch.
	 * @param	Y				The Y position of the screen touch.
	 * @param	SearchRadius	How far from the touch point to search.
	 * @return	The nearest tower, as a Tower object.
	 */
	private function getNearestTower( X:Float, Y:Float, SearchRadius:Float ):Tower
	{
		var minDistance:Float = SearchRadius;
		var closestTower:Tower = null;
		var searchPoint:FlxPoint = new FlxPoint( X, Y );
		
		for ( tower in _towerGroup.members ) {
			var dist:Float = FlxMath.getDistance( searchPoint, tower.getMidpoint() );
			
			if ( dist < minDistance ) {
				closestTower = tower;
				minDistance = dist;
			}
		}
		
		return closestTower;
	}
	#end
	
	/**
	 * Called when an enemy collides with a goal. Explodes the enemy, damages the goal.
	 */
	private function hitGoal( enemy:Dynamic, goal:Dynamic ):Void
	{
		_lives--;
		enemy.explode( false );
		
		if ( _lives >= 0 ) {
			_lifeGroup.members[ _lives ].kill();
		}
		
		if ( _lives == 0 ) {
			loseGame();
		}
		
		#if !js
		FlxG.sound.play( "hurt" );
		#end
	}
	
	/**
	 * Called when a bullet hits an enemy. Damages the enemy, kills the bullet.
	 */
	private function hitEnemy( bullet:Dynamic, enemy:Dynamic ):Void
	{
		enemy.hurt( bullet.damage );
		bullet.kill();
		
		#if !js
		FlxG.sound.play( "enemyhit" );
		#end
	}
	
	/**
	 * A function that is called when the user enters build mode.
	 * @param	Skip
	 */
	private function buildTowerCallback( Skip:Bool = false ):Void
	{
		if ( ( !_guiGroup.visible || towerPrice > money ) && !Skip ) {
			return;
		}
		
		_buildingMode = !_buildingMode;
		_towerRange.visible = !_towerRange.visible;
		_buildHelper.visible = _buildingMode;
		
		playSelectSound();
	}
	
	/**
	 * A function that is called when the user changes game speed.
	 */
	private function speedButtonCallback(Skip:Bool = false):Void
	{
		if ( !_guiGroup.visible && !Skip ) {
			return;
		}
		
		if ( _speed < 3 ) {
			_speed += 1;
		} else {
			_speed = 1;
		}
		
		FlxG.timeScale = _speed;
		_speedButton.text = "x" + _speed;
		
		playSelectSound();
	}
	
	/**
	 * A function that is called when the user leaves building mode.
	 */
	private function escapeBuilding( Skip:Bool = false ):Void
	{
		toggleUpgradeMenu( false );
		_buildingMode = false;
		_buildHelper.visible = _buildingMode;
	}
	
	/**
	 * A function that is called when the user selects to call the next wave.
	 */
	private function nextWaveCallback(Skip:Bool = false):Void
	{
		if ( !_guiGroup.visible && !Skip ) {
			return;
		}
		
		if ( enemiesToKill > 0 ) {
			return;
		}
		
		spawnWave();
		playSelectSound();
	}
	
	/**
	 * A function that is called when the user elects to restart, which is only possible after losing.
	 */
	private function resetCallback(Skip:Bool = false):Void
	{
		if ( !_guiGroup.visible && !Skip ) {
			return;
		}
		
		FlxG.resetState();
		playSelectSound();
	}
	
	/**
	 * A function that attempts to build a tower when the user clicks on the playable space. Must have money,
	 * and be building in a valid place (not on another tower, the road, or the GUI).
	 */
	private function buildTower():Void
	{
		// Can't place towers on GUI
		
		if ( FlxG.mouse.y > FlxG.height - 16 ) {
			return;
		}
		
		// Can't buy towers without money
		
		if ( money < towerPrice ) {
			#if !js
			FlxG.sound.play("deny");
			#end
			
			escapeBuilding();
			return;
		}
		
		// Snap to grid
		
		var xPos:Float = FlxG.mouse.x - ( FlxG.mouse.x % 8 );
		var yPos:Float = FlxG.mouse.y - ( FlxG.mouse.y % 8 );
		
		// Can't place towers on other towers
		
		for ( tower in _towerGroup.members ) {
			if ( tower.x == xPos && tower.y == yPos ) {
				#if !js
				FlxG.sound.play("deny");
				#end
				escapeBuilding();
				return;
			}
		}
		
		//Can't place towers on the road
		
		if ( _map.getTile( Std.int( xPos / 8 ), Std.int( yPos / 8 ) ) == 0 )
		{
			#if !js
			FlxG.sound.play("deny");
			#end
			
			escapeBuilding();
			return;
		}
		
		_towerGroup.add( new Tower( xPos, yPos ) ); 
		
		#if !js
		FlxG.sound.play( "build" );
		#end
		
		money -= towerPrice;
		towerPrice += Std.int( towerPrice * 0.3 );
		_towerButton.text = "Buy [T]ower ($" + towerPrice + ")";
		escapeBuilding();
	}
	
	/**
	 * The select sound gets played from a lot of places, so it's in a convenient function.
	 */
	private function playSelectSound():Void
	{
		#if !js
		FlxG.sound.play( "select" );
		#end
	} 
	
	/**
	 * Used to display either the wave number or Game Over message via the animated fly-in, fly-out text.
	 * 
	 * @param	End		Whether or not this is the end of the game. If true, message will say "Game Over! :("
	 */
	private function announceWave( End:Bool = false ):Void
	{
		_centerText.x = -200;
		_centerText.text = "Wave " + wave;
		
		if ( End ) {
			_centerText.text = "Game Over! :(";
		}
		
		FlxTween.multiVar( _centerText, { x: 0 }, 2, { ease: FlxEase.expoOut, complete: hideText } );
		
		_waveText.text = "Wave: " + wave;
		_waveText.size = 16;
		_waveText.visible = true;
	}
	
	/**
	 * Hides the center text message display on announceWave, once the first tween is complete.
	 */
	private function hideText( Tween:FlxTween ):Void
	{
		FlxTween.multiVar( _centerText, { x: FlxG.width }, 2, { ease: FlxEase.expoIn } );
	}
	
	/**
	 * Spawns the next wave. This increments the wave variable, displays the center text message,
	 * sets the number of enemies to spawn and kill, hides the next wave button, and shows the
	 * notification of the number of enemies.
	 */
	private function spawnWave():Void
	{
		if ( _gameOver ) {
			return;
		}
		
		wave ++;
		announceWave();
		enemiesToKill = 5 + wave;
		enemiesToSpawn = enemiesToKill;
		
		_nextWaveButton.visible = false;
		
		if ( !_upgradeHasBeenBought ) {
			_tutText.visible = true;
		}
		
		_enemyText.visible = true;
		_enemyText.size = 16;
	}
	
	/**
	 * Spawns an enemy. Decrements the enemiesToSpawn variable, and recycles an enemy from enemyGroup and then initiates
	 * it and gives it a path to follow.
	 */
	private function spawnEnemy():Void
	{
		enemiesToSpawn--;
		
		var enemy:Enemy = enemyGroup.recycle(Enemy);
		enemy.init( _enemySpawnX, _enemySpawnY );
		enemy.followPath( _map.findPath( new FlxPoint( _enemySpawnX, 0), new FlxPoint( _goalX + 5, _goalY + 5 ) ) );
		_spawnCounter = 0;
	}
	
	/**
	 * Called when you lose. Of course!
	 */
	private function loseGame():Void
	{
		_gameOver = true;
		
		enemyGroup.kill();
		towerIndicators.kill();
		_towerGroup.kill();
		_upgradeMenu.kill();
		_towerRange.kill();
		
		announceWave( true );
		
		_towerButton.text = "[R]estart";
		_towerButton.setOnDownCallback( resetCallback );
		
		#if !js
		FlxG.sound.play("gameover");
		#end
	}
	
	/**
	 * Called either when building, or upgrading, a tower.
	 */
	private function updateRangeSprite( Center:FlxPoint, Range:Int ):Void
	{
		_towerRange.setPosition( Center.x - Range, Center.y - Range );
		_towerRange.makeGraphic( Range * 2, Range * 2, FlxColor.TRANSPARENT );
		
		var sprite:Sprite = new Sprite();
		sprite.graphics.beginFill( 0xFFFFFF );
		sprite.graphics.drawCircle( Range, Range, Range );
		sprite.graphics.endFill();
		
		_towerRange.pixels.draw( sprite );
		_towerRange.blend = BlendMode.INVERT;
		_towerRange.visible = true;
	}
	
	/**
	 * Toggles the upgrade menu and tower range indicator.
	 */
	private function toggleUpgradeMenu( On:Bool ):Void
	{
		_upgradeMenu.visible = On;
		_guiGroup.visible = !On;
		_towerRange.visible = On;
		
		if ( !On ) {
			_towerSelected = null;
		} else {
			updateUpgradeLabels();
		}
		
		if ( On ) {
			playSelectSound();
		}
	}
	
	/**
	 * Called when the user attempts to update range. If they have enough money, the upgradeRange() function
	 * for this tower is called, and the money is decreased.
	 */
	private function upgradeRangeCallback():Void
	{
		if ( !_upgradeMenu.visible ) {
			return;
		}
		
		if ( money >= _towerSelected.range_PRIZE ) {
			money -= _towerSelected.range_PRIZE;
			_towerSelected.upgradeRange();
			upgradeHelper();
		}
	}
	
	/**
	 * Called when the user attempts to update damage. If they have enough money, the upgradeDamage() function
	 * for this tower is called, and the money is decreased.
	 */
	private function upgradeDamageCallback():Void
	{
		if ( !_upgradeMenu.visible ) {
			return;
		}
		
		if ( money >= _towerSelected.damage_PRIZE ) {
			money -= _towerSelected.damage_PRIZE;
			_towerSelected.upgradeDamage();
			upgradeHelper();
		}
	}
	
	/**
	 * Called when the user attempts to update fire rate. If they have enough money, the upgradeFirerate() function
	 * for this tower is called, and the money is decreased.
	 */
	private function upgradeFirerateCallback():Void
	{
		if ( !_upgradeMenu.visible ) {
			return;
		}
		
		if ( money >= _towerSelected.firerate_PRIZE ) {
			money -= _towerSelected.firerate_PRIZE;
			_towerSelected.upgradeFirerate();
			upgradeHelper();
		}
	}
	
	/**
	 * Called after an upgrade. Updates button text, plays a sound, and sets the upgrade bought flag to true.
	 */
	private function upgradeHelper():Void
	{
		updateUpgradeLabels();
		playSelectSound();
		_upgradeHasBeenBought = true;
	}
	
	/**
	 * Update button labels for upgrades, and makes sure the range indicator sprite is updated.
	 */
	private function updateUpgradeLabels():Void
	{
		_rangeButton.text = "Range (" + _towerSelected.range_LEVEL + "): $" + _towerSelected.range_PRIZE; 
		_damageButton.text = "Damage (" + _towerSelected.damage_LEVEL + "): $" + _towerSelected.damage_PRIZE; 
		_firerateButton.text = "Firerate (" + _towerSelected.firerate_LEVEL + "): $" + _towerSelected.firerate_PRIZE; 
		
		updateRangeSprite( _towerSelected.getMidpoint(), _towerSelected.range );
	}
	
	/**
	 * Controls how money is handled. Setting money automatically "balloons" the money HUD indicator.
	 */
	public var money(get, set):Int;
	
	private function get_money():Int
	{
		return _money;
	}
	
	private function set_money( NewMoney:Int ):Int
	{
		#if debug
		if ( MONEY_CHEAT ) return _money;
		#end
		_money = NewMoney;
		_moneyText.text = "$: " + _money;
		_moneyText.size = 16;
		
		return _money;
	}
}