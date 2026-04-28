from manim import *

class PrismToNet(ThreeDScene):
    def construct(self):
        # 1. Dimensions
        l, w, h = 3, 2, 1
        
        # 2. Create the Faces
        # Bottom sits in the XY plane
        bottom = Rectangle(width=l, height=w, fill_opacity=0.5, color=BLUE)
        top = Rectangle(width=l, height=w, fill_opacity=0.5, color=BLUE)
        
        # Sides
        front = Rectangle(width=l, height=h, fill_opacity=0.5, color=RED)
        back = Rectangle(width=l, height=h, fill_opacity=0.5, color=RED)
        left = Rectangle(width=h, height=w, fill_opacity=0.5, color=GREEN)
        right = Rectangle(width=h, height=w, fill_opacity=0.5, color=GREEN)

        # 3. Initial Positioning (Forming the Prism)
        # Position the top directly above the bottom
        top.move_to(OUT * h)
        
        # Rotate and snap sides to the edges of the bottom face
        front.rotate(90*DEGREES, axis=RIGHT).move_to(bottom.get_bottom(), aligned_edge=UP)
        back.rotate(90*DEGREES, axis=RIGHT).move_to(bottom.get_top(), aligned_edge=DOWN)
        left.rotate(90*DEGREES, axis=UP).move_to(bottom.get_left(), aligned_edge=RIGHT)
        right.rotate(90*DEGREES, axis=UP).move_to(bottom.get_right(), aligned_edge=LEFT)

        prism = VGroup(bottom, top, front, back, left, right)
        
        # 4. Camera Setup
        self.set_camera_orientation(phi=75 * DEGREES, theta=-45 * DEGREES)
        self.add(prism)
        self.wait(1)

        # 5. Opening Animation
        # We rotate 90 degrees around the shared edge (about_point)
        self.play(
            Rotate(front, angle=90*DEGREES, axis=RIGHT, about_point=bottom.get_bottom()),
            Rotate(back, angle=-90*DEGREES, axis=RIGHT, about_point=bottom.get_top()),
            Rotate(left, angle=90*DEGREES, axis=UP, about_point=bottom.get_left()),
            Rotate(right, angle=-90*DEGREES, axis=UP, about_point=bottom.get_right()),
            # Move the top face along with the 'back' face
            Rotate(top, angle=-90*DEGREES, axis=RIGHT, about_point=bottom.get_top()),
            run_time=2
        )
        
        # Final step: Open the top face relative to the back face
        self.play(
            Rotate(top, angle=-90*DEGREES, axis=RIGHT, about_point=back.get_top()),
            run_time=2
        )
        self.wait(2)

