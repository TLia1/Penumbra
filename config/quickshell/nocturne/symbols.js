.pragma library

// Symbols for the launcher's Symbols mode: [character, name], grouped. The group name is searched too.
var groups = [
    ["Letters", [
        ["É", "e acute capital"], ["È", "e grave capital"], ["Ê", "e circumflex capital"], ["Ë", "e diaeresis capital"],
        ["À", "a grave capital"], ["Â", "a circumflex capital"], ["Ç", "c cedilla capital"], ["Ù", "u grave capital"],
        ["Û", "u circumflex capital"], ["Ô", "o circumflex capital"], ["Î", "i circumflex capital"], ["Ï", "i diaeresis capital"],
        ["Œ", "oe ligature capital"], ["œ", "oe ligature"], ["Æ", "ae ligature capital"], ["æ", "ae ligature"],
        ["ß", "sharp s eszett"], ["ñ", "n tilde"], ["Ñ", "n tilde capital"], ["ø", "o stroke"], ["å", "a ring"],
        ["ÿ", "y diaeresis"], ["ı", "dotless i"], ["ð", "eth"], ["þ", "thorn"]
    ]],
    ["Punctuation", [
        ["«", "left guillemet quote"], ["»", "right guillemet quote"], ["“", "left double quote"], ["”", "right double quote"],
        ["‘", "left single quote"], ["’", "right single quote apostrophe"], ["„", "low double quote"], ["‚", "low single quote"],
        ["—", "em dash"], ["–", "en dash"], ["‑", "non-breaking hyphen"], ["…", "ellipsis"], ["•", "bullet"],
        ["·", "middle dot interpunct"], ["‣", "triangular bullet"], ["¡", "inverted exclamation"], ["¿", "inverted question"],
        ["‽", "interrobang"], ["§", "section"], ["¶", "pilcrow paragraph"], ["†", "dagger"], ["‡", "double dagger"],
        ["※", "reference mark"], ["′", "prime minute foot"], ["″", "double prime second inch"], ["‰", "per mille"],
        ["‱", "per ten thousand"], ["№", "numero number"], ["⁂", "asterism"], [" ", "non-breaking space nbsp"],
        [" ", "narrow non-breaking space"]
    ]],
    ["Legal", [
        ["©", "copyright"], ["®", "registered"], ["™", "trademark"], ["℠", "service mark"], ["℗", "sound recording copyright"]
    ]],
    ["Currency", [
        ["€", "euro"], ["£", "pound sterling"], ["¥", "yen yuan"], ["¢", "cent"], ["₹", "indian rupee"], ["₽", "ruble"],
        ["₩", "won"], ["₺", "turkish lira"], ["₴", "hryvnia"], ["₪", "shekel"], ["₫", "dong"], ["₿", "bitcoin"],
        ["฿", "baht"], ["₱", "peso"], ["¤", "currency sign"]
    ]],
    ["Math", [
        ["±", "plus minus"], ["∓", "minus plus"], ["×", "multiply times"], ["÷", "divide"], ["−", "minus"], ["≠", "not equal"],
        ["≈", "approximately"], ["≡", "identical"], ["≤", "less or equal"], ["≥", "greater or equal"], ["≪", "much less"],
        ["≫", "much greater"], ["∞", "infinity"], ["√", "square root"], ["∛", "cube root"], ["∑", "sum sigma"],
        ["∏", "product"], ["∫", "integral"], ["∬", "double integral"], ["∮", "contour integral"], ["∂", "partial derivative"],
        ["∇", "nabla del gradient"], ["∆", "increment delta"], ["∝", "proportional"], ["∅", "empty set"], ["∈", "element of"],
        ["∉", "not element of"], ["∋", "contains"], ["⊂", "subset"], ["⊃", "superset"], ["⊆", "subset or equal"],
        ["⊇", "superset or equal"], ["∪", "union"], ["∩", "intersection"], ["∀", "for all"], ["∃", "there exists"],
        ["∄", "there does not exist"], ["¬", "not negation"], ["∧", "and conjunction"], ["∨", "or disjunction"],
        ["⊕", "xor circled plus"], ["⊗", "tensor circled times"], ["⊥", "perpendicular bottom"], ["∥", "parallel"],
        ["∠", "angle"], ["°", "degree"], ["℃", "degree celsius"], ["℉", "degree fahrenheit"],
        ["ℕ", "natural numbers"], ["ℤ", "integers"], ["ℚ", "rationals"], ["ℝ", "real numbers"], ["ℂ", "complex numbers"],
        ["ℵ", "aleph"], ["∴", "therefore"], ["∵", "because"], ["∘", "ring composition"], ["⋅", "dot operator"],
        ["⌈", "left ceiling"], ["⌉", "right ceiling"], ["⌊", "left floor"], ["⌋", "right floor"], ["⟨", "left angle bracket"],
        ["⟩", "right angle bracket"], ["µ", "micro"], ["‖", "double vertical norm"]
    ]],
    ["Fractions", [
        ["½", "one half"], ["⅓", "one third"], ["⅔", "two thirds"], ["¼", "one quarter"], ["¾", "three quarters"],
        ["⅕", "one fifth"], ["⅙", "one sixth"], ["⅛", "one eighth"], ["⅜", "three eighths"], ["⅝", "five eighths"],
        ["⅞", "seven eighths"]
    ]],
    ["Superscript", [
        ["⁰", "superscript zero"], ["¹", "superscript one"], ["²", "superscript two squared"], ["³", "superscript three cubed"],
        ["⁴", "superscript four"], ["⁵", "superscript five"], ["⁶", "superscript six"], ["⁷", "superscript seven"],
        ["⁸", "superscript eight"], ["⁹", "superscript nine"], ["⁺", "superscript plus"], ["⁻", "superscript minus"],
        ["ⁿ", "superscript n"], ["ⁱ", "superscript i"], ["ᵉ", "superscript e"], ["ʳ", "superscript r"],
        ["ᵃ", "superscript a"], ["ᵒ", "superscript o"]
    ]],
    ["Subscript", [
        ["₀", "subscript zero"], ["₁", "subscript one"], ["₂", "subscript two"], ["₃", "subscript three"],
        ["₄", "subscript four"], ["₅", "subscript five"], ["₆", "subscript six"], ["₇", "subscript seven"],
        ["₈", "subscript eight"], ["₉", "subscript nine"], ["₊", "subscript plus"], ["₋", "subscript minus"],
        ["ₓ", "subscript x"], ["ₙ", "subscript n"]
    ]],
    ["Greek", [
        ["α", "alpha"], ["β", "beta"], ["γ", "gamma"], ["δ", "delta"], ["ε", "epsilon"], ["ζ", "zeta"], ["η", "eta"],
        ["θ", "theta"], ["ι", "iota"], ["κ", "kappa"], ["λ", "lambda"], ["μ", "mu"], ["ν", "nu"], ["ξ", "xi"],
        ["ο", "omicron"], ["π", "pi"], ["ρ", "rho"], ["σ", "sigma"], ["ς", "final sigma"], ["τ", "tau"], ["υ", "upsilon"],
        ["φ", "phi"], ["χ", "chi"], ["ψ", "psi"], ["ω", "omega"], ["Γ", "gamma capital"], ["Δ", "delta capital"],
        ["Θ", "theta capital"], ["Λ", "lambda capital"], ["Ξ", "xi capital"], ["Π", "pi capital"], ["Σ", "sigma capital"],
        ["Φ", "phi capital"], ["Ψ", "psi capital"], ["Ω", "omega capital ohm"]
    ]],
    ["Arrows", [
        ["←", "left arrow"], ["→", "right arrow"], ["↑", "up arrow"], ["↓", "down arrow"], ["↔", "left right arrow"],
        ["↕", "up down arrow"], ["↖", "up left arrow"], ["↗", "up right arrow"], ["↘", "down right arrow"],
        ["↙", "down left arrow"], ["⇐", "left double arrow"], ["⇒", "right double arrow implies"], ["⇑", "up double arrow"],
        ["⇓", "down double arrow"], ["⇔", "left right double arrow iff"], ["⟵", "long left arrow"], ["⟶", "long right arrow"],
        ["⟷", "long left right arrow"], ["⟹", "long right double arrow"], ["↦", "maps to"], ["↩", "return left hook arrow"],
        ["↪", "right hook arrow"], ["↺", "counterclockwise arrow"], ["↻", "clockwise arrow"], ["⇄", "right left arrows"],
        ["⇆", "left right arrows"], ["➜", "heavy right arrow"], ["➤", "arrowhead right"], ["⤴", "curve up arrow"],
        ["⤵", "curve down arrow"]
    ]],
    ["Keys", [
        ["⌘", "command key"], ["⌥", "option alt key"], ["⇧", "shift key"], ["⌃", "control key"], ["⇪", "caps lock key"],
        ["⏎", "return enter key"], ["↵", "enter key"], ["⌫", "backspace key"], ["⌦", "delete key"], ["⎋", "escape key"],
        ["⇥", "tab key"], ["⇤", "backtab key"], ["␣", "space key"], ["⏏", "eject"], ["⎙", "print screen"]
    ]],
    ["Shapes", [
        ["■", "black square"], ["□", "white square"], ["▪", "small black square"], ["▫", "small white square"],
        ["●", "black circle"], ["○", "white circle"], ["◉", "fisheye"], ["◎", "bullseye"], ["◆", "black diamond"],
        ["◇", "white diamond"], ["▲", "black up triangle"], ["△", "white up triangle"], ["▼", "black down triangle"],
        ["▽", "white down triangle"], ["◀", "black left triangle"], ["▶", "black right triangle play"], ["★", "black star"],
        ["☆", "white star"], ["✦", "four pointed star"], ["✧", "white four pointed star"], ["✶", "six pointed star"],
        ["❖", "diamond minus x"], ["♥", "heart suit"], ["♡", "white heart"], ["♦", "diamond suit"], ["♣", "club suit"],
        ["♠", "spade suit"], ["✓", "check mark"], ["✔", "heavy check mark"], ["✗", "ballot x cross"], ["✘", "heavy ballot x"],
        ["☐", "ballot box"], ["☑", "ballot box checked"], ["☒", "ballot box x"], ["█", "full block"], ["░", "light shade"],
        ["▒", "medium shade"], ["▓", "dark shade"]
    ]],
    ["Box drawing", [
        ["─", "box horizontal"], ["│", "box vertical"], ["┌", "box down right corner"], ["┐", "box down left corner"],
        ["└", "box up right corner"], ["┘", "box up left corner"], ["├", "box vertical right tee"], ["┤", "box vertical left tee"],
        ["┬", "box down tee"], ["┴", "box up tee"], ["┼", "box cross"], ["═", "box double horizontal"],
        ["║", "box double vertical"], ["╭", "box rounded down right"], ["╮", "box rounded down left"],
        ["╰", "box rounded up right"], ["╯", "box rounded up left"]
    ]],
    ["Miscellaneous", [
        ["♪", "eighth note music"], ["♫", "beamed notes music"], ["♭", "flat"], ["♯", "sharp"], ["♮", "natural"],
        ["☀", "sun"], ["☁", "cloud"], ["☂", "umbrella"], ["☃", "snowman"], ["❄", "snowflake"], ["☾", "moon crescent"],
        ["⚡", "lightning high voltage"], ["☎", "telephone"], ["✉", "envelope"], ["✎", "pencil"], ["✂", "scissors"],
        ["⚙", "gear"], ["⚠", "warning"], ["☢", "radioactive"], ["☣", "biohazard"], ["☮", "peace"], ["☯", "yin yang"],
        ["♀", "female"], ["♂", "male"], ["⚧", "transgender"], ["☕", "hot beverage coffee"], ["⌛", "hourglass"],
        ["⌚", "watch"], ["✝", "latin cross"], ["☠", "skull crossbones"], ["♻", "recycling"], ["⚓", "anchor"]
    ]]
];
