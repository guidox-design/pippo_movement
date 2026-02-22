extends CharacterBody2D

enum STATE {
	FALL,
	FLOOR,
	JUMP,
	DOUBLE_JUMP,
	FLOAT,
	LEDGE_CLIMB,
	LEDGE_JUMP,
	ATTACK,
	WALL_SLIDE,
	WALL_JUMP,
	WALL_CLIMB,
	DASH,
	TURNING,
}

const FALL_GRAVITY := 1500.0
const FALL_VELOCITY := 500.0
const WALK_VELOCITY := 200.0
const JUMP_VELOCITY := -600.0
const JUMP_DECELERATION := 1500.0
const DOUBLE_JUMP_VELOCITY := -450.0
const FLOAT_GRAVITY := 200.0
const FLOAT_VELOCITY := 100.0
const LEDGE_JUMP_VELOCITY := -500
const WALL_SLIDE_GRAVITY := 300.0
const WALL_SLIDE_VELOCITY := 500.0
const WALL_JUMP_LENGTH := 30.0
const WALL_JUMP_VELOCITY := -500.0
const WALL_CLIMB_VELOCITY := -300.0
const WALL_CLIMB_LENGTH := 65.0
const DASH_LENGTH := 100.0
const DASH_VELOCITY := 600.0



@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var float_cool_down: Timer = $FloatCoolDown
@onready var player_collider: CollisionShape2D = $PlayerCollider
@onready var ledge_climb_ray_cast: RayCast2D = $LedgeClimbRayCast
@onready var ledge_space_ray_cast: RayCast2D = $LedgeSpaceRayCast
@onready var wall_slide_ray_cast: RayCast2D = $WallSlideRayCast
@onready var dash_cooldown: Timer = $DashCooldown


var active_state := STATE.FALL
var can_double_jump := false
var facing_direction := 1.0
var saved_position := Vector2.ZERO
var can_dash := false
var dash_jump_buffer := false


func _ready() -> void:
	switch_state(active_state)
	ledge_climb_ray_cast.add_exception(self)




func _physics_process(delta: float) -> void:
	process_state(delta)
	move_and_slide()
	#handle_input()
	
	
	
	
	
func switch_state(to_state: STATE) -> void:
	var previous_state := active_state
	active_state = to_state

## State specific things that need to run only once upon entering the next state	
	match active_state:
		STATE.FALL:
			if previous_state != STATE.DOUBLE_JUMP: 
				animated_sprite.play("fall")
				if previous_state == STATE.FLOOR:
					coyote_timer.start()
			
		STATE.FLOOR:
			can_double_jump = true
			can_dash = true
			
		STATE.JUMP:
			animated_sprite.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
		
		STATE.DOUBLE_JUMP:
			animated_sprite.play("double_jump")
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false
	
	
		STATE.FLOAT:
			if float_cool_down.time_left > 0:
				active_state = previous_state
				return
			animated_sprite.play("float")
			velocity.y = 0

		STATE.LEDGE_CLIMB:
			animated_sprite.play("ledge_climb")
			velocity = Vector2.ZERO
			global_position.y = ledge_climb_ray_cast.get_collision_point().y
			can_double_jump = true


		STATE.LEDGE_JUMP:
			animated_sprite.play("double_jump")
			velocity.y = LEDGE_JUMP_VELOCITY
			can_dash = true

		STATE.WALL_SLIDE:
			animated_sprite.play("wall_slide")
			velocity.y = 0
			can_double_jump = true
			can_dash = true

		STATE.WALL_JUMP:
			animated_sprite.play("jump")
			velocity.y = WALL_JUMP_VELOCITY
			set_facing_direction(-facing_direction)
			saved_position = position


		STATE.WALL_CLIMB:
			animated_sprite.play("wall_climb")
			velocity.y = WALL_CLIMB_VELOCITY
			saved_position = position

		STATE.DASH:
			if dash_cooldown.time_left > 0:
				active_state = previous_state
				return
			animated_sprite.play("dash")
			velocity.y = 0
			set_facing_direction(sign(Input.get_axis("move_left", "move_right")))
			velocity.x = facing_direction * DASH_VELOCITY
			saved_position = position
			can_dash = previous_state == STATE.FLOOR or previous_state == STATE.WALL_SLIDE
			dash_jump_buffer = false


func process_state(delta: float) -> void:
	match active_state:
		
		STATE.FALL:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			handle_movement()
			
			if is_on_floor():
				switch_state(STATE.FLOOR)
				
			elif Input.is_action_just_pressed("jump"):
				if coyote_timer.time_left > 0:
					switch_state(STATE.JUMP)
				elif can_double_jump:
					switch_state(STATE.DOUBLE_JUMP)
				else:
					switch_state(STATE.FLOAT)
			elif is_input_toward_facing() and is_ledge() and is_space():
				switch_state(STATE.LEDGE_CLIMB)
			elif is_input_toward_facing() and can_wall_sliding():
				switch_state(STATE.WALL_SLIDE)
			elif Input.is_action_just_pressed("sprint") and can_dash:
				switch_state(STATE.DASH)

		STATE.FLOOR:
			if Input.get_axis("move_left", "move_right"):
				animated_sprite.play("walk")
			else:
				animated_sprite.play("idle")
			handle_movement()
			
			if not is_on_floor():
				switch_state(STATE.FALL)
				
			elif Input.is_action_just_pressed("jump"):
				switch_state(STATE.JUMP)

			elif Input.is_action_just_pressed("sprint"):
				switch_state(STATE.DASH)


		STATE.JUMP, STATE.DOUBLE_JUMP, STATE.LEDGE_JUMP, STATE.WALL_JUMP:
			velocity.y = move_toward(velocity.y, 0, JUMP_DECELERATION * delta)
			if active_state == STATE.WALL_JUMP:
				var distance := absf(position.x - saved_position.x)
				if distance >= WALL_JUMP_LENGTH or can_wall_sliding():
					active_state = STATE.JUMP
				else:
					handle_movement(facing_direction)

			if active_state != STATE.WALL_JUMP:
				handle_movement()
			
			if Input.is_action_just_released("jump") or velocity.y >= 0:
				velocity.y = 0
				switch_state(STATE.FALL)

			elif Input.is_action_just_pressed("jump"):
				switch_state(STATE.DOUBLE_JUMP)	
			
			elif Input.is_action_just_pressed("sprint") and can_dash:
				switch_state(STATE.DASH)


		STATE.FLOAT:
			velocity.y = move_toward(velocity.y, FLOAT_VELOCITY, FLOAT_GRAVITY * delta)
			handle_movement()
			
			if is_on_floor():
				switch_state(STATE.FLOOR)
			elif Input.is_action_just_released("jump"):
				float_cool_down.start()
				switch_state(STATE.FALL)
			elif is_input_toward_facing() and is_ledge() and is_space():
				switch_state(STATE.LEDGE_CLIMB)
			elif is_input_toward_facing() and can_wall_sliding():
				switch_state(STATE.WALL_SLIDE)

			elif Input.is_action_just_pressed("sprint") and can_dash:
				switch_state(STATE.DASH)


		STATE.LEDGE_CLIMB:
			if not animated_sprite.is_playing():
				animated_sprite.play("idle")
				var offset := ledge_climb_offset()
				offset.x *= facing_direction
				position += offset
				switch_state(STATE.FLOOR)
			elif Input.is_action_just_pressed("jump"):
				var progress := inverse_lerp(0, animated_sprite.sprite_frames.get_frame_count("ledge_climb"), animated_sprite.frame)
				var offset := ledge_climb_offset()
				offset.x *= facing_direction * progress
				position += offset 
				switch_state(STATE.LEDGE_JUMP)


		STATE.WALL_SLIDE:
			velocity.y = move_toward(velocity.y, WALL_SLIDE_VELOCITY, WALL_SLIDE_GRAVITY * delta)
			handle_movement()

			if is_on_floor():
				switch_state(STATE.FLOOR)
			
			elif is_ledge() and is_space():
				switch_state(STATE.LEDGE_CLIMB)
			
			elif not can_wall_sliding():
				switch_state(STATE.FALL)
			
			elif Input.is_action_just_pressed("jump"):
				switch_state(STATE.WALL_JUMP)
			
			elif Input.is_action_just_pressed("sprint"):
				if is_input_toward_facing():
					switch_state(STATE.WALL_CLIMB)
				else:
					set_facing_direction(-facing_direction)
					switch_state(STATE.DASH)
		
		STATE.WALL_CLIMB:
			var distance := absf(position.y - saved_position.y)
			if distance >= WALL_CLIMB_LENGTH or is_on_ceiling():
				velocity.y = 0
				switch_state(STATE.WALL_SLIDE)
			elif is_ledge():
				switch_state(STATE.LEDGE_JUMP)

		STATE.DASH:
			dash_cooldown.start()
			if is_on_floor():
				coyote_timer.start()
			if Input.is_action_just_pressed("jump"):
				dash_jump_buffer = true
			var distance := absf(position.x - saved_position.x)
			if distance >= DASH_LENGTH or signf(get_last_motion().x) != facing_direction:
				if dash_jump_buffer and coyote_timer.time_left > 0:
					switch_state(STATE.JUMP)
				elif is_on_floor():
					switch_state(STATE.FLOOR)	
				else:
					switch_state(STATE.FALL)

			elif is_ledge() and is_space():
				switch_state(STATE.LEDGE_CLIMB)
			elif can_wall_sliding():
				switch_state(STATE.WALL_SLIDE)
			


	
func handle_movement(input_direction: float = 0) -> void:
	if input_direction == 0: 
		input_direction = signf(Input.get_axis("move_left", "move_right"))
	set_facing_direction(input_direction)
	velocity.x = input_direction * WALK_VELOCITY


func set_facing_direction(direction: float) -> void:
	if direction:
		animated_sprite.flip_h = direction < 0
		facing_direction = direction

		#aggiornamento direzione dei raycast in direzione frontale al personaggio
		ledge_climb_ray_cast.position.x = direction * absf(ledge_climb_ray_cast.position.x)
		ledge_climb_ray_cast.target_position.x = direction * absf(ledge_climb_ray_cast.target_position.x)
		wall_slide_ray_cast.force_raycast_update()
		wall_slide_ray_cast.position.x = direction * absf(wall_slide_ray_cast.position.x)
		wall_slide_ray_cast.target_position.x = direction * absf(wall_slide_ray_cast.target_position.x)
		wall_slide_ray_cast.force_raycast_update()



#verifica che l'input del player sia lo stesso della direzione del personaggio
func is_input_toward_facing() -> bool:
	return signf(Input.get_axis("move_left", "move_right")) == facing_direction


func is_ledge() -> bool:
	return is_on_wall_only() and \
	ledge_climb_ray_cast.is_colliding() and \
	ledge_climb_ray_cast.get_collision_normal().is_equal_approx(Vector2.UP)

func is_space() -> bool:
	ledge_space_ray_cast.global_position = ledge_space_ray_cast.get_collision_point()
	ledge_space_ray_cast.force_raycast_update()
	return not ledge_space_ray_cast.is_colliding()


func ledge_climb_offset() -> Vector2:
	var shape := player_collider.shape
	if shape is CapsuleShape2D:
		return Vector2(shape.radius * 2.0, -shape.height * 0.5)
	if shape is RectangleShape2D:
		return Vector2(shape.size.x, -shape.size.y * 0.5)
	return Vector2.ZERO



func can_wall_sliding() -> bool:
	return is_on_wall_only() and wall_slide_ray_cast.is_colliding()


