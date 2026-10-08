.pragma library

// Paleta escura do Google Keep (a mesma do celular) e o tom da barra de cima,
// mais vivo, como nas Notas Autoadesivas do Windows 11.
var palette = {
    "DEFAULT":  { name: "Padrão",       body: "#2b2c30", bar: "#4a4c52" },
    "RED":      { name: "Vermelho",     body: "#77172e", bar: "#b4294a" },
    "ORANGE":   { name: "Laranja",      body: "#692b17", bar: "#b4501f" },
    "YELLOW":   { name: "Amarelo",      body: "#7c4a03", bar: "#c58a12" },
    "GREEN":    { name: "Verde",        body: "#264d3b", bar: "#3f8b62" },
    "TEAL":     { name: "Azul-petróleo", body: "#0c625d", bar: "#159b92" },
    "BLUE":     { name: "Azul",         body: "#256377", bar: "#3a95b2" },
    "CERULEAN": { name: "Azul-escuro",  body: "#284255", bar: "#41698a" },
    "PURPLE":   { name: "Roxo",         body: "#472e5b", bar: "#7a4f9c" },
    "PINK":     { name: "Rosa",         body: "#6c394f", bar: "#a95a7c" },
    "BROWN":    { name: "Marrom",       body: "#4b443a", bar: "#7d7262" },
    "GRAY":     { name: "Cinza",        body: "#3c3f43", bar: "#62666c" }
};

function body(c) { return (palette[c] || palette.DEFAULT).body; }
function bar(c) { return (palette[c] || palette.DEFAULT).bar; }
function name(c) { return (palette[c] || palette.DEFAULT).name; }

// "agora", "há 5 min", "14:03", "3 de out."
function when(seconds) {
    if (!seconds) return "";
    var d = new Date(seconds * 1000);
    var diff = (Date.now() - d.getTime()) / 60000;
    if (diff < 1) return "agora";
    if (diff < 60) return "há " + Math.floor(diff) + " min";
    if (new Date().toDateString() === d.toDateString())
        return Qt.locale().toString(d, Qt.locale().timeFormat(1 /* Locale.ShortFormat */));
    // no idioma do sistema ("8 de ago."); de outro ano, com o ano
    return Qt.locale().toString(d, d.getFullYear() === new Date().getFullYear() ? "d MMM" : "d MMM yyyy");
}
