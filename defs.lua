interp.macro {
  name = 'a', arg = true;
  "killapp()",
  ".m %s",
  "goapp '%s'",
}

interp.macro {
    name = 'ml', arg = true;
    ".m %s",
    "require '%s'",
}

interp.macro {
    name = 'd', arg = true;
    '.l %s.lua',
    'draw.view:invalidate()'
}

interp.macro {
    name = 'md', arg = true;
    '.m %s',
    'require "%s"'
}



