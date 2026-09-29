package com.fasoresto.core.io

/**
 * Petit lecteur / écrivain JSON sans dépendance, suffisant pour la sauvegarde
 * de l'application. Objets → Map<String, Any?>, tableaux → List<Any?>,
 * nombres → Long ou Double.
 */
object Json {

    fun lire(texte: String): Any? = Lecteur(texte).run {
        val v = valeur()
        espaces()
        require(pos == texte.length) { "Caractères en trop à la position $pos" }
        v
    }

    fun ecrire(valeur: Any?): String = StringBuilder().also { ecrire(valeur, it) }.toString()

    private fun ecrire(v: Any?, sb: StringBuilder) {
        when (v) {
            null -> sb.append("null")
            is Boolean, is Int, is Long -> sb.append(v)
            is Double -> sb.append(if (v % 1.0 == 0.0) v.toLong().toString() else v.toString())
            is String -> chaine(v, sb)
            is Map<*, *> -> {
                sb.append('{')
                v.entries.forEachIndexed { i, (k, x) ->
                    if (i > 0) sb.append(',')
                    chaine(k.toString(), sb); sb.append(':'); ecrire(x, sb)
                }
                sb.append('}')
            }
            is Iterable<*> -> {
                sb.append('[')
                v.forEachIndexed { i, x -> if (i > 0) sb.append(','); ecrire(x, sb) }
                sb.append(']')
            }
            else -> chaine(v.toString(), sb)
        }
    }

    private fun chaine(s: String, sb: StringBuilder) {
        sb.append('"')
        for (c in s) when (c) {
            '"' -> sb.append("\\\"")
            '\\' -> sb.append("\\\\")
            '\n' -> sb.append("\\n")
            '\r' -> sb.append("\\r")
            '\t' -> sb.append("\\t")
            else -> if (c < ' ') sb.append("\\u%04x".format(c.code)) else sb.append(c)
        }
        sb.append('"')
    }

    private class Lecteur(val s: String) {
        var pos = 0

        fun espaces() {
            while (pos < s.length && s[pos].isWhitespace()) pos++
        }

        fun valeur(): Any? {
            espaces()
            require(pos < s.length) { "JSON incomplet" }
            return when (val c = s[pos]) {
                '{' -> objet()
                '[' -> tableau()
                '"' -> chaine()
                't' -> mot("true", true)
                'f' -> mot("false", false)
                'n' -> mot("null", null)
                else -> if (c == '-' || c.isDigit()) nombre() else error("Caractère inattendu '$c' à la position $pos")
            }
        }

        private fun mot(m: String, v: Any?): Any? {
            require(s.startsWith(m, pos)) { "« $m » attendu à la position $pos" }
            pos += m.length
            return v
        }

        private fun objet(): Map<String, Any?> {
            val m = LinkedHashMap<String, Any?>()
            pos++
            espaces()
            if (s[pos] == '}') { pos++; return m }
            while (true) {
                espaces()
                val k = chaine()
                espaces()
                require(s[pos] == ':') { "':' attendu à la position $pos" }
                pos++
                m[k] = valeur()
                espaces()
                when (s[pos++]) {
                    ',' -> continue
                    '}' -> return m
                    else -> error("',' ou '}' attendu à la position ${pos - 1}")
                }
            }
        }

        private fun tableau(): List<Any?> {
            val l = ArrayList<Any?>()
            pos++
            espaces()
            if (s[pos] == ']') { pos++; return l }
            while (true) {
                l += valeur()
                espaces()
                when (s[pos++]) {
                    ',' -> continue
                    ']' -> return l
                    else -> error("',' ou ']' attendu à la position ${pos - 1}")
                }
            }
        }

        private fun chaine(): String {
            require(s[pos] == '"') { "Texte attendu à la position $pos" }
            pos++
            val sb = StringBuilder()
            while (true) {
                val c = s[pos++]
                when (c) {
                    '"' -> return sb.toString()
                    '\\' -> when (val e = s[pos++]) {
                        'n' -> sb.append('\n')
                        'r' -> sb.append('\r')
                        't' -> sb.append('\t')
                        'b' -> sb.append('\b')
                        'f' -> sb.append('\u000C')
                        'u' -> { sb.append(s.substring(pos, pos + 4).toInt(16).toChar()); pos += 4 }
                        else -> sb.append(e)
                    }
                    else -> sb.append(c)
                }
            }
        }

        private fun nombre(): Any {
            val debut = pos
            while (pos < s.length && (s[pos].isDigit() || s[pos] in "+-.eE")) pos++
            val t = s.substring(debut, pos)
            return t.toLongOrNull() ?: t.toDouble()
        }
    }
}
