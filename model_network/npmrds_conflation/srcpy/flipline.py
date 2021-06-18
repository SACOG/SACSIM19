# reverse the direction of a line based on its endpoints

def reverse_line(line_geom):
        x_start = line_geom.firstPoint.X
        y_start = line_geom.firstPoint.Y
        x_end = line_geom.lastPoint.X
        y_end = line_geom.lastPoint.Y