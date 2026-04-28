from manim import *


class CubeSurfaceArea(ThreeDScene):
    def construct(self):
        # ── configurable side length ──────────────────────────────────────────
        s = 2

        # ── camera setup ─────────────────────────────────────────────────────
        self.set_camera_orientation(phi=65 * DEGREES, theta=-45 * DEGREES, zoom=0.9)

        # ══════════════════════════════════════════════════════════════════════
        # PART 1 – solid cube, slow rotation so students see it's 3D
        # ══════════════════════════════════════════════════════════════════════
        cube = Cube(side_length=s, fill_opacity=1, fill_color=BLUE_E,
                    stroke_color=WHITE, stroke_width=2)

        title = Text("Surface Area of a Cube", font_size=36, color=WHITE)
        title.to_corner(UL)
        self.add_fixed_in_frame_mobjects(title)
        title.to_corner(UL)

        self.play(FadeIn(cube, shift=IN * 0.5), run_time=1.5)
        self.wait(0.5)

        self.begin_ambient_camera_rotation(rate=0.25)
        self.wait(3)
        self.stop_ambient_camera_rotation()

        # ══════════════════════════════════════════════════════════════════════
        # PART 2 – "open" into wireframe (transparent faces, visible edges)
        # ══════════════════════════════════════════════════════════════════════
        wire_label = Text("Wireframe view", font_size=28, color=YELLOW)
        wire_label.to_corner(UR)
        self.add_fixed_in_frame_mobjects(wire_label)
        wire_label.to_corner(UR)

        wireframe_anims = [
            face.animate.set_fill(opacity=0.08).set_stroke(WHITE, width=3)
            for face in cube
        ]
        self.play(*wireframe_anims, run_time=2)
        self.wait(1)

        self.play(FadeOut(wire_label), run_time=0.4)
        self.remove(wire_label)

        # ══════════════════════════════════════════════════════════════════════
        # PART 3 – color each face one by one while rotating
        # ══════════════════════════════════════════════════════════════════════
        face_colors = [RED, GREEN, BLUE_B, YELLOW, ORANGE, PINK]
        face_names  = ["Face 1", "Face 2", "Face 3", "Face 4", "Face 5", "Face 6"]

        face_label = Text(face_names[0], font_size=28, color=face_colors[0])
        face_label.to_corner(UR)
        self.add_fixed_in_frame_mobjects(face_label)
        face_label.to_corner(UR)

        self.begin_ambient_camera_rotation(rate=0.18)

        for i, (face, color, name) in enumerate(zip(cube, face_colors, face_names)):
            new_label = Text(name, font_size=28, color=color)
            new_label.to_corner(UR)
            self.add_fixed_in_frame_mobjects(new_label)
            new_label.to_corner(UR)

            self.play(
                face.animate.set_fill(color, opacity=0.75).set_stroke(color, width=3),
                FadeOut(face_label),
                FadeIn(new_label),
                run_time=0.9,
            )
            self.remove(face_label)
            face_label = new_label
            self.wait(0.4)

        self.stop_ambient_camera_rotation()
        self.wait(0.5)

        # ══════════════════════════════════════════════════════════════════════
        # PART 4 – fade 3D scene, move to 2D formula view
        # ══════════════════════════════════════════════════════════════════════
        self.play(FadeOut(face_label), run_time=0.3)
        self.remove(face_label)

        self.move_camera(phi=60 * DEGREES, theta=-60 * DEGREES, zoom=0.85, run_time=1.5)
        self.wait(0.5)

        self.play(FadeOut(cube), FadeOut(title), run_time=1.2)
        self.remove(title)
        self.wait(0.3)

        self.move_camera(phi=0 * DEGREES, theta=-90 * DEGREES, zoom=1, run_time=1)

        # ══════════════════════════════════════════════════════════════════════
        # PART 5 – 2D formula view (no LaTeX — uses Text only)
        # ══════════════════════════════════════════════════════════════════════
        s_sq = s * s
        sa   = 6 * s_sq

        # ── square representing one face ──────────────────────────────────────
        sq_size = 2.2
        square = Square(side_length=sq_size, fill_color=RED, fill_opacity=0.55,
                        stroke_color=WHITE, stroke_width=2)

        brace_h     = Brace(square, direction=DOWN, color=YELLOW)
        brace_h_lbl = brace_h.get_text(f"s = {s}", buff=0.1)
        brace_h_lbl.set_color(YELLOW)

        brace_v     = Brace(square, direction=RIGHT, color=YELLOW)
        brace_v_lbl = brace_v.get_text(f"s = {s}", buff=0.1)
        brace_v_lbl.set_color(YELLOW)

        face_area_lbl = Text(f"Face area = s x s = s²  =  {s}² = {s_sq}",
                             font_size=28, color=WHITE)
        face_area_lbl.next_to(square, DOWN, buff=1.0)

        sq_group = VGroup(square, brace_h, brace_h_lbl, brace_v, brace_v_lbl,
                          face_area_lbl)
        sq_group.shift(LEFT * 2.8 + UP * 0.3)

        self.add_fixed_in_frame_mobjects(sq_group)
        sq_group.shift(LEFT * 2.8 + UP * 0.3)   # re-position after pinning

        # ── formula lines ─────────────────────────────────────────────────────
        t_size = 30   # font size for formula block

        formula_title = Text("Surface Area Formula", font_size=34, color=YELLOW,
                             weight=BOLD)
        line1 = Text("A cube has 6 faces",          font_size=t_size, color=WHITE)
        line2 = Text("Each face  =  s²",            font_size=t_size, color=WHITE)
        line3 = Text("SA  =  6 × s²",               font_size=t_size + 4, color=GREEN)
        line4 = Text(f"s  =  {s}",                  font_size=t_size, color=YELLOW)
        line5 = Text(f"SA  =  6 × {s_sq}  =  {sa}", font_size=t_size + 4, color=ORANGE)

        formula_title.move_to(RIGHT * 2.0 + UP * 2.4)
        line1.next_to(formula_title, DOWN, buff=0.35)
        line2.next_to(line1,         DOWN, buff=0.20)
        line3.next_to(line2,         DOWN, buff=0.30)
        line4.next_to(line3,         DOWN, buff=0.20)
        line5.next_to(line4,         DOWN, buff=0.30)

        answer_box = SurroundingRectangle(line5, color=ORANGE, buff=0.18, corner_radius=0.1)

        rhs_group = VGroup(formula_title, line1, line2, line3, line4, line5, answer_box)

        self.add_fixed_in_frame_mobjects(rhs_group)
        # re-position after pinning (Manim quirk for fixed-frame objects)
        formula_title.move_to(RIGHT * 2.0 + UP * 2.4)
        line1.next_to(formula_title, DOWN, buff=0.35)
        line2.next_to(line1,         DOWN, buff=0.20)
        line3.next_to(line2,         DOWN, buff=0.30)
        line4.next_to(line3,         DOWN, buff=0.20)
        line5.next_to(line4,         DOWN, buff=0.30)
        answer_box.become(SurroundingRectangle(line5, color=ORANGE, buff=0.18,
                                               corner_radius=0.1))
        self.add_fixed_in_frame_mobjects(answer_box)

        # ── animate the 2D view ───────────────────────────────────────────────
        self.play(FadeIn(square), run_time=0.8)
        self.play(
            GrowFromCenter(brace_h), Write(brace_h_lbl),
            GrowFromCenter(brace_v), Write(brace_v_lbl),
            run_time=1.0,
        )
        self.play(Write(face_area_lbl), run_time=1.0)
        self.wait(0.5)

        self.play(Write(formula_title), run_time=0.7)
        self.play(Write(line1), run_time=0.6)
        self.play(Write(line2), run_time=0.6)
        self.play(Write(line3), run_time=0.8)
        self.play(Write(line4), run_time=0.6)
        self.play(Write(line5), run_time=0.8)
        self.play(Create(answer_box), run_time=0.6)
        self.wait(3)

        self.play(
            FadeOut(sq_group),
            FadeOut(rhs_group),
            FadeOut(answer_box),
            run_time=1.5,
        )
        self.wait(0.5)


# ── entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    config.media_width = "75%"
    config.quality = "medium_quality"
    scene = CubeSurfaceArea()
    scene.render()
