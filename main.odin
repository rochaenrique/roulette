package roulette

import "core:fmt"
import "core:c"
import "core:os"
import "core:math"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

normalize_angle :: proc(angle: f32) -> int {
	return (int(angle)%360 + 360) % 360
}

is_sector_picked :: proc(start_angle, end_angle: f32) -> bool {
	n_start := normalize_angle(start_angle)
	n_end := normalize_angle(end_angle)

	if n_start < n_end do return n_start <= 0 && n_end > 0
	return n_start <= 0 || n_end > 0
}

State :: enum {
	Idle,
	Picking,
	Removing,
}

empty_log_callback :: proc "c" (logLevel: rl.TraceLogLevel, text: cstring, args: ^c.va_list) {
	return 
}

main :: proc() {
	rl.SetTraceLogCallback(empty_log_callback)
	rl.InitWindow(800, 800, "Roulette")
	
	font := rl.GetFontDefault()
	font_size := f32(40)
	font_spacing := f32(5)

	texts: [dynamic]string
	append(&texts, ..os.args[1:])
	circle_segments := i32(20)
	
	begin_angle := f32(0)
	rotation_speed := f32(0)

	pick_timer := f32(0)
	pick_timer_min := f32(2)
	pick_timer_max := f32(5)
	pick_timer_slow := f32(2)
	max_pick_speed := f32(720)

	state := State.Idle

	picked_index := -1
	
	for !rl.WindowShouldClose() {
		window_width := rl.GetScreenWidth()
		window_height := rl.GetScreenHeight()
		window_size := rl.Vector2{f32(window_width), f32(window_height)}
		window_center := window_size / 2
		delta := rl.GetFrameTime()

		if rl.IsKeyDown(.ENTER) {
			pick_timer = rand.float32_range(pick_timer_min, pick_timer_max)
			rotation_speed = max_pick_speed

			if state == .Removing && picked_index != -1 {
				ordered_remove(&texts, picked_index)
				picked_index = -1
			}
			state = .Picking
		}

		switch state {
		case .Idle: {
			if rl.IsKeyDown(.UP) do font_size += 1
			if rl.IsKeyDown(.DOWN) do font_size -= 1
			if rl.IsKeyDown(.LEFT) do rotation_speed += 10
			if rl.IsKeyDown(.RIGHT) do rotation_speed -= 10
		}
		case .Picking: {
			pick_timer -= delta
			
			if pick_timer > 0 {
				if pick_timer < pick_timer_slow {
					rotation_speed = max_pick_speed * (pick_timer/pick_timer_slow)
				} 
			} else {
				state = .Removing
				pick_timer = f32(0)
				rotation_speed = 0
			}
		}
		case .Removing:  {
		}
		}
		
		begin_angle += rotation_speed*delta

		max_text_width := f32(0)
		for text, index in texts {
			cstring_text := strings.unsafe_string_to_cstring(text)
			text_size := rl.MeasureTextEx(font, cstring_text, font_size, font_spacing)
			if text_size.x > max_text_width {
				max_text_width = text_size.x			
			}
		}

		circle_radius := max_text_width * 1.5
		circle_center := window_center
		
		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.BLACK)

			angle_increment := 360.0/f32(len(texts))

			picker_edge_position := rl.Vector2{circle_center.x + circle_radius, circle_center.y}
			v2 := picker_edge_position+rl.Vector2{20, 20}
			v3 := picker_edge_position+rl.Vector2{20,-20}
			rl.DrawTriangle(picker_edge_position, v2, v3, rl.YELLOW)

			for text, index in texts {
				start_angle := begin_angle + angle_increment * f32(index)
				end_angle := f32(start_angle + angle_increment)
				
				color := rl.ColorLerp(rl.RED, rl.BLUE, f32(index)/f32(len(texts)))
				
				rl.DrawCircleSector(circle_center, circle_radius, start_angle, end_angle, circle_segments, color)

				cstring_text := strings.unsafe_string_to_cstring(text)
				text_size := rl.MeasureTextEx(font, cstring_text, font_size, font_spacing)
				text_rotation := (start_angle + end_angle)/2.0
				text_origin := rl.Vector2{-circle_radius*.2, text_size.y/2}

				is_picked := is_sector_picked(start_angle, end_angle)
				if is_picked do picked_index = index
				text_color := is_picked ? rl.YELLOW : rl.WHITE
				rl.DrawTextPro(font, cstring_text, circle_center, text_origin, text_rotation, font_size, font_spacing, text_color)
			}
		}
		rl.EndDrawing()
	}
	
	rl.CloseWindow()
}
