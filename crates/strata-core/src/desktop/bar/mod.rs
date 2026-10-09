#[derive(Clone, Copy, Debug)]
pub enum Position {
    Top,
    Bottom,
    Left,
    Right,
}

#[derive(Clone, Copy, Debug)]
pub enum Transparency {
    True,
    False,
    Toggle,
}
