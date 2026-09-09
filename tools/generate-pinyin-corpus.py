#!/usr/bin/env python3
"""Erzeugt den datengestützten Teil des Pinyin-Golden-Corpus.

Der Corpus misst, ob die App einem Lernenden die **gesprochene** Form zeigt.
Die Sollwerte dürfen deshalb nicht aus der Swift-Implementierung stammen
(Phase-6.5-Vorgabe §19). Sie kommen aus genau drei Quellen, und jeder Fall
trägt seine Quelle in der Spalte `basis`:

1. **CC-CEDICT** — für die lexikalische Lesung und den neutralen Ton. Das ist
   die Datenquelle der App, aber die Ableitung hier ist unabhängig: Die
   Tonzeichen setzt der Renderer unten, geschrieben aus der Platzierungsregel
   in GB/T 16159-2012 und ausdrücklich **kein** Port von `PinyinTone.swift`.
2. **北京语言大学, 现代汉语** — für die Sandhi-Regeln. Zitate stehen in
   `CApp/Services/ToneSandhi.swift` und in `docs/architecture.md` A28/A29.
3. **Produktentscheidung** — dort, wo die App bewusst von der
   Wörterbuchschreibung abweicht oder eine Regel bewusst *nicht* anwendet.

Von Hand stehen in `pinyin-corpus-manual.tsv`: E (längere Folgen dritter
Töne), F (`一`), G (`不`), J (Fallback) und K (Wortgrenzen). Dieses Skript
rührt jene Datei nicht an.

**Was dieser Teil belegen kann und was nicht.** Die Kategorien A, B, C, D, H
und I falsifizieren die Auflösung, die Segmentierung, die Unit-Grenzen und die
Zerlegung — nicht den Regelinhalt selbst, denn `third_tone_surface` und
`sentence_reading` bilden die Regeln nach. Bei I liegt die Unabhängigkeit in
der **von Hand gesetzten Wortsegmentierung**, nicht in den Tönen. Die
Regelinhalte prüfen die handgeschriebenen Kategorien und
`CAppTests/ToneSandhiTests.swift`.

Aufruf aus dem Repository-Wurzelverzeichnis:

    python3 tools/generate-pinyin-corpus.py
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "CApp" / "Resources" / "ThirdParty" / "CC-CEDICT"
OUT = ROOT / "CAppTests" / "Resources" / "pinyin-corpus.tsv"
MANUAL = ROOT / "CAppTests" / "Resources" / "pinyin-corpus-manual.tsv"

# --- Tonzeichen, unabhängig gesetzt ---------------------------------------
#
# Regel aus GB/T 16159-2012: Das Tonzeichen steht auf dem Hauptvokal; bei
# `iu` und `ui` auf dem zweiten Buchstaben. Ton 5 ist der neutrale Ton und
# trägt kein Zeichen.

MARKS = {
    "a": "āáǎà",
    "e": "ēéěè",
    "i": "īíǐì",
    "o": "ōóǒò",
    "u": "ūúǔù",
    "ü": "ǖǘǚǜ",
}
VOWELS = "aeiouü"


def marked(field: str) -> str:
    """`guo3` → `guǒ`, `nu:e4` → `nüè`, `xi5` → `xi`."""
    text = field.replace("u:", "ü").replace("U:", "Ü")
    if not text or not text[-1].isdigit():
        return text
    tone, letters = int(text[-1]), text[:-1]
    if tone == 5:
        return letters
    index = vowel_index(letters.lower())
    if index is None:
        return letters
    character = letters[index]
    replacement = MARKS[character.lower()][tone - 1]
    if character.isupper():
        replacement = replacement.upper()
    return letters[:index] + replacement + letters[index + 1 :]


def vowel_index(letters: str) -> int | None:
    for vowel in "aoe":
        if vowel in letters:
            return letters.index(vowel)
    for pair in ("iu", "ui"):
        if pair in letters:
            return letters.index(pair) + 1
    for index in range(len(letters) - 1, -1, -1):
        if letters[index] in VOWELS:
            return index
    return None


def rendered(reading: str, tones: list[int] | None = None) -> str:
    """Eine ganze Lesung, optional mit ersetzten Tönen."""
    fields = reading.split(" ")
    if tones is not None:
        fields = [f[:-1] + str(t) for f, t in zip(fields, tones)]
    return "".join(marked(f) for f in fields)


# --- Daten ----------------------------------------------------------------


def load() -> tuple[dict[str, str], set[str]]:
    readings: dict[str, str] = {}
    for line in (DATA / "cedict-readings.txt").read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or "\t" not in line:
            continue
        word, reading = line.split("\t", 1)
        readings[word] = reading
    ambiguous = {
        line.strip()
        for line in (DATA / "cedict-ambiguous.txt").read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("#")
    }
    return readings, ambiguous


def tones_of(reading: str) -> list[int]:
    return [int(f[-1]) for f in reading.split(" ") if f and f[-1].isdigit()]


def is_proper_noun(reading: str) -> bool:
    """Ob CC-CEDICT die Lesung als Eigennamen führt.

    Großschreibung ist das Signal — gemessen 18.957 Einträge im Snapshot.
    Solche Einträge fliegen aus den automatischen Kategorien: `阿法尔` und
    `宝坻区` sind kein Lernwortschatz, und ob Sandhi in einer Namens-
    Transliteration überhaupt gilt, ist eine Frage, die dieser Corpus nicht
    beantworten soll. Kategorie F prüft Eigennamen gezielt (`一月`).
    """
    return any(field[:1].isupper() for field in reading.split(" "))


def is_clean(word: str, reading: str) -> bool:
    """Ein Stichwort, reines Han, genau eine Silbe je Zeichen, jede mit Ton.

    Die Silbenzahl wird geprüft, nicht angenommen: 13 Einträge schreiben zwei
    Silben ohne Trennzeichen (`兙` liest `shi2ke4`), und solche Lesungen
    dürfen keinen Sollwert erzeugen.
    """
    fields = reading.split(" ")
    return (
        len(fields) == len(word)
        and all(f and f[-1].isdigit() for f in fields)
        and all("一" <= c <= "鿿" for c in word)
    )


def third_tone_surface(reading: str) -> list[int]:
    """Die gesprochenen Töne **innerhalb eines Stichworts**.

    Gilt nur für Wörter mit **höchstens zwei** dritten Tönen in Folge; dort
    ist die Verzweigung belanglos. Bei drei dritten Tönen entscheidet sie
    (双单格 2-2-3 gegen 单双格 3-2-3), und dann gehört der Fall von Hand nach
    pinyin-corpus-manual.tsv. Geprüft: keiner der hier erzeugten C-, H- und
    I-Fälle hat drei dritte Töne in Folge.

    Regel: 北京语言大学, 现代汉语 — „两个上声前后行，前头那个变阳平". Für drei
    Silben im 双单格 werden die ersten zwei zu 阳平; das ergibt sich aus
    derselben Formulierung, sobald man sie auf die *lexikalischen* Töne
    anwendet und nicht iterativ auf das Ergebnis. Deshalb liest die Bedingung
    hier `base`, nie `surface`.
    """
    base = tones_of(reading)
    surface = list(base)
    for index in range(len(base) - 1):
        if base[index] == 3 and base[index + 1] == 3:
            surface[index] = 2
    return surface


# --- Kategorien -----------------------------------------------------------

# A — gewöhnliche Wörter ohne jeden Sandhi-Auslöser. Sollwert ist die
# Wörterbuchlesung; wer hier abweicht, hat ein Problem in der Grundauflösung.
BASIC = """
苹果 西瓜 香蕉 面包 牛奶 咖啡 米饭 鸡蛋 蔬菜 医生
老师 工人 司机 警察 厨师 农民 律师 北京 上海 中国
德国 法国 日本 美国 英国 韩国 火车站 飞机场 图书馆 博物馆
电影院 邮局 公园 明天 昨天 今天 中午 星期 天气 汉语
英语 问题 照片 学校 教室 报纸 手机 电视 冰箱 空调
自行车 出租车 地铁 机票 护照 行李 房间 钥匙 电话 邮票
""".split()

# C — Zeichen, die allein mehrdeutig sind und erst im Wort eindeutig werden.
# Sollwert ist die Lesung des **Phrasen**-Stichworts, nicht die eines Zeichens.
POLYPHONE = """
银行 行为 进行 旅行 长大 长期 校长 生长 东西南北 买东西
音乐 快乐 大夫 大家 大学 个人 一个人 号码 口号 为了
因为 认为 作为 教书 教室 还是 还有 重要 重复 差别
只有 只好 中间 中国 得到 觉得 睡觉 便宜 方便 好处
""".split()

CATEGORIES = [
    ("A", "Grundwortschatz ohne Sandhi", BASIC, "CC-CEDICT"),
    ("C", "Polyphone im Wortkontext", POLYPHONE, "CC-CEDICT Phrase"),
]


# I — Alltagssätze. Die **Wortsegmentierung steht hier von Hand**, die Töne
# leitet das Skript daraus mechanisch ab. Diese Trennung ist der Punkt: Wie
# ein Satz in Wörter fällt, ist ein sprachliches Urteil und darf nicht aus
# derselben Quelle kommen wie die Implementierung; welchen Ton eine Silbe
# dann trägt, ist mechanisch und soll nicht von Hand getippt werden.
#
# Ein erster Anlauf ließ Python selbst per Longest Match segmentieren. Das
# reproduzierte genau den Fehler, den A23 dokumentiert: `我不明白` wurde zu
# `我`+`不明`+`白` und ergab `wǒbùmíngbái` statt `wǒbùmíngbai`. Ein falscher
# Sollwert ist schlimmer als keiner, also entscheidet die Segmentierung jetzt
# ein Mensch.
SENTENCES = [
    ("我是学生", ["我", "是", "学生"]),
    ("他是老师", ["他", "是", "老师"]),
    ("这是我的书", ["这", "是", "我", "的", "书"]),
    ("我有一个问题", ["我", "有", "一个", "问题"]),
    ("明天我去学校", ["明天", "我", "去", "学校"]),
    ("我想喝咖啡", ["我", "想", "喝", "咖啡"]),
    ("我要吃面包", ["我", "要", "吃", "面包"]),
    ("她喜欢香蕉", ["她", "喜欢", "香蕉"]),
    ("我不知道", ["我", "不", "知道"]),
    ("我不明白", ["我", "不", "明白"]),
    ("这个不错", ["这个", "不错"]),
    ("我在图书馆", ["我", "在", "图书馆"]),
    ("她在教室里", ["她", "在", "教室", "里"]),
    ("我们去公园", ["我们", "去", "公园"]),
    ("请等一下", ["请", "等", "一下"]),
    ("对不起我迟到了", ["对不起", "我", "迟到", "了"]),
    ("谢谢你的帮助", ["谢谢", "你", "的", "帮助"]),
    ("不客气", ["不客气"]),
    ("早上好", ["早上", "好"]),
    ("你叫什么名字", ["你", "叫", "什么", "名字"]),
    ("我二十岁", ["我", "二十", "岁"]),
    ("你住在哪里", ["你", "住", "在", "哪里"]),
    ("我住在北京", ["我", "住", "在", "北京"]),
    ("火车站在哪里", ["火车站", "在", "哪里"]),
    ("我要买机票", ["我", "要", "买", "机票"]),
    ("便宜一点", ["便宜", "一点"]),
    ("我想去博物馆", ["我", "想", "去", "博物馆"]),
    ("我每天六点起床", ["我", "每天", "六", "点", "起床"]),
    ("他七点吃早饭", ["他", "七", "点", "吃", "早饭"]),
    ("我们八点上课", ["我们", "八", "点", "上课"]),
    ("她九点下班", ["她", "九", "点", "下班"]),
    ("我十点睡觉", ["我", "十", "点", "睡觉"]),
    ("今天是星期一", ["今天", "是", "星期一"]),
    ("明天是我的生日", ["明天", "是", "我", "的", "生日"]),
    ("我有两个哥哥", ["我", "有", "两个", "哥哥"]),
    ("她有一个妹妹", ["她", "有", "一个", "妹妹"]),
    ("我的房间很小", ["我", "的", "房间", "很", "小"]),
    ("这本书很有意思", ["这", "本", "书", "很", "有意思"]),
    ("我学习汉语一年了", ["我", "学习", "汉语", "一", "年", "了"]),
    ("他工作很忙", ["他", "工作", "很", "忙"]),
    ("我们一起去吃饭", ["我们", "一起", "去", "吃饭"]),
    ("我还没吃", ["我", "还", "没", "吃"]),
    ("我已经吃了", ["我", "已经", "吃", "了"]),
    ("请给我一杯水", ["请", "给", "我", "一", "杯", "水"]),
    ("今天天气很好", ["今天", "天气", "很", "好"]),
    ("我很喜欢中国", ["我", "很", "喜欢", "中国"]),
    ("他会说汉语", ["他", "会", "说", "汉语"]),
    ("这里有洗手间吗", ["这里", "有", "洗手间", "吗"]),
    ("我想喝一杯茶", ["我", "想", "喝", "一", "杯", "茶"]),
    ("他不来了", ["他", "不", "来", "了"]),
    ("我不要这个", ["我", "不", "要", "这个"]),
    ("这个太贵了", ["这个", "太", "贵", "了"]),
    ("我们明天见", ["我们", "明天", "见"]),
    ("你好吗", ["你好", "吗"]),
    ("我很好谢谢", ["我", "很好", "谢谢"]),
    ("他有一本书", ["他", "有", "一", "本", "书"]),
    ("我要一份米饭", ["我", "要", "一", "份", "米饭"]),
    ("请再说一遍", ["请", "再", "说", "一遍"]),
    ("我听不懂", ["我", "听", "不", "懂"]),
    ("这是什么", ["这", "是", "什么"]),
]


def sentence_reading(sentence, words, readings, ambiguous):
    """Die erwartete Lernaussprache eines Satzes, ohne Leerzeichen.

    `words` ist die von Hand gesetzte Wortsegmentierung. Von dort an rein
    mechanisch: Lesung je Wort aus CC-CEDICT, dritter Ton **innerhalb** eines
    Wortes, `一` und `不` lokal über die ganze Kette — die beiden hängen am
    Zeichen und nicht an einer prosodischen Domäne (A28).

    `None`, wenn ein Wort keine eindeutige Lesung hat. Solche Sätze gehören
    nach Kategorie J, nicht in eine Quote über korrekte Aussprache.
    """
    if "".join(words) != sentence:
        raise SystemExit(f"Segmentierung passt nicht zum Satz: {sentence} / {words}")

    units = []
    for word in words:
        if word in ambiguous:
            return None
        reading = readings.get(word)
        if reading is None or not is_clean(word, reading):
            return None
        units.append((word, tones_of(reading), reading))

    surfaces = [third_tone_surface(reading) for _word, _tones, reading in units]

    flat_chars, flat_base, position = [], [], []
    for unit_index, (word, tones, _reading) in enumerate(units):
        for offset, character in enumerate(word):
            flat_chars.append(character)
            flat_base.append(tones[offset])
            position.append((unit_index, offset))

    numbers = set("一二三四五六七八九十百千万亿零两")
    # Ein neutralisierter Ton löst die 一-Regel nach seinem **etymologischen**
    # Ton aus: `一个` ist `yi1 ge5` in den Daten und wird `yíge` gesprochen,
    # weil `个` zugrunde ein vierter Ton ist. Diese kleine Tabelle steht hier
    # von Hand, damit die Ableitung **unabhängig** von der App bleibt — die
    # holt sich denselben Grundton aus `cedict-base-tones.txt` (A30). Beide
    # Wege kommen aus derselben sprachlichen Tatsache, aber nicht aus
    # demselben Code, und genau das soll der Corpus prüfen können.
    etymological = {"个": 4}
    for flat, character in enumerate(flat_chars):
        base = flat_base[flat]
        following = flat_base[flat + 1] if flat + 1 < len(flat_chars) else None
        if following == 5 and flat + 1 < len(flat_chars):
            following = etymological.get(flat_chars[flat + 1], 5)
        previous_char = flat_chars[flat - 1] if flat > 0 else None
        next_char = flat_chars[flat + 1] if flat + 1 < len(flat_chars) else None
        unit_index, offset = position[flat]
        if character == "一" and base == 1 and following in (1, 2, 3, 4):
            if previous_char == "第" or previous_char in numbers:
                continue
            if next_char in numbers:
                continue
            if previous_char is not None and previous_char == next_char:
                continue
            surfaces[unit_index][offset] = 2 if following == 4 else 4
        elif character == "不" and base == 4 and following == 4:
            if previous_char is not None and previous_char == next_char:
                continue
            surfaces[unit_index][offset] = 2

    return "".join(
        rendered(reading, surfaces[unit_index])
        for unit_index, (_word, _tones, reading) in enumerate(units)
    )


def main() -> int:
    readings, ambiguous = load()
    rows: list[tuple[str, str, str, str, str]] = []
    skipped: list[str] = []

    def add(category: str, word: str, expected: str, review: str, basis: str) -> None:
        rows.append((category, word, expected, review, basis))

    # A und C: Sollwert ist die reine Wörterbuchlesung.
    for category, _label, words, basis in CATEGORIES:
        for word in dict.fromkeys(words):
            reading = readings.get(word)
            if reading is None or word in ambiguous or not is_clean(word, reading):
                skipped.append(f"{category} {word}: kein eindeutiges reines Stichwort")
                continue
            tones = tones_of(reading)
            if category == "A":
                if 5 in tones or any(
                    tones[i] == 3 and tones[i + 1] == 3 for i in range(len(tones) - 1)
                ) or "一" in word or "不" in word:
                    skipped.append(f"A {word}: gehört in eine Regelkategorie")
                    continue
                add(category, word, rendered(reading), "false", basis)
                continue
            # C prüft die Polyphon-Auflösung, schließt Sandhi aber nicht aus:
            # `只有` ist `zhi3 you3` und wird `zhíyǒu` gesprochen, `一个人`
            # ist `yi1 ge4 ren2` und wird `yígèrén` gesprochen. Ein erster
            # Anlauf nahm hier die rohe Lesung als Sollwert und meldete drei
            # Fehler, die keine waren.
            expected = sentence_reading(word, [word], readings, ambiguous)
            if expected is None:
                skipped.append(f"C {word}: keine ableitbare Lesung")
                continue
            add(category, word, expected, "false", basis + " + BLCU-Regeln")

    # B: neutraler Ton. Aus den Daten gezogen statt handverlesen, damit der
    # Satz nicht nur aus den vier Beispielen besteht, die man kennt. Bedingung:
    # genau zwei Silben, die zweite Ton 5, kein weiterer Auslöser.
    neutral = []
    for word, reading in readings.items():
        if word in ambiguous or not is_clean(word, reading) or is_proper_noun(reading):
            continue
        tones = tones_of(reading)
        if len(tones) != 2 or tones[1] != 5 or tones[0] == 3:
            continue
        if "一" in word or "不" in word:
            continue
        neutral.append((word, reading))
    # Deterministisch: nach Häufigkeit im Alltag lässt sich hier nicht
    # sortieren, also alphabetisch nach Lesung und dann die bekannten Fälle
    # zuerst, damit der Satz stabil bleibt und im Diff lesbar ist.
    known = ["谢谢", "东西", "明白", "朋友", "妈妈", "爸爸", "哥哥", "弟弟",
             "妹妹", "孩子", "衣服", "事情", "时候", "地方", "工夫", "先生",
             "太太", "什么", "怎么", "多么", "这么", "那么", "喜欢", "知道",
             "看见", "认识", "休息", "便宜", "困难", "萝卜", "葡萄", "石头"]
    neutral_map = dict(neutral)
    ordered = [w for w in known if w in neutral_map]
    ordered += [w for w, _ in sorted(neutral, key=lambda p: p[1]) if w not in set(ordered)]
    for word in ordered[:40]:
        add("B", word, rendered(neutral_map[word]), "false", "CC-CEDICT (Ton 5)")

    # D und E: dritter Ton vor drittem Ton, innerhalb **eines** Stichworts.
    # Sollwert nach der zitierten Regel, angewandt auf die lexikalischen Töne.
    third_two, third_long = [], []
    for word, reading in readings.items():
        if word in ambiguous or not is_clean(word, reading) or is_proper_noun(reading):
            continue
        tones = tones_of(reading)
        if not any(tones[i] == 3 and tones[i + 1] == 3 for i in range(len(tones) - 1)):
            continue
        if "一" in word or "不" in word:
            continue
        (third_two if len(tones) == 2 else third_long).append((word, reading))

    # Von Hand vorgeschlagen, jeder Fall gegen die Daten geprüft — **ohne**
    # automatische Auffüllung. Ein erster Anlauf füllte auf, und das Ergebnis
    # war wertlos: alphabetisch nach Lesung sortiert kamen `把屎`, `百脚`,
    # `矮丑穷`, `把马子` und Transliterationen wie `阿尔法` heraus. Solche Fälle
    # prüfen denselben Codepfad wie `你好`, treiben aber die Gesamtquote nach
    # oben, ohne etwas über die Lernerfahrung zu sagen — genau die
    # Scheingenauigkeit, die §3 der Phasenvorgabe verbietet. Lieber 36 echte
    # Fälle als 36 aufgefüllte.
    d_known = ["你好", "水果", "手表", "美好", "可以", "所以", "语法", "打扫",
               "洗澡", "老板", "指导", "选举", "表演", "领导", "友好", "也许",
               "只有", "起点", "早晚", "允许", "保守", "广场", "处理", "管理",
               "展览", "总统", "雨伞", "老虎", "打死", "洗手", "理想", "有理",
               "小组", "首领", "保管", "尽管"]
    e_known = ["展览馆", "洗手间", "总统府", "水彩笔", "打火机", "养老院",
               "小老鼠", "指导者", "手写体", "水果酒", "管理员", "打点滴",
               "小姐姐", "小雨伞", "纸老虎", "小酒馆", "小拇指", "所有者",
               "广场舞", "处理者", "保守党", "冷处理", "使领馆", "导火索"]

    def pick(pool, first, limit, curated_only=False):
        pool_map = dict(pool)
        ordered = [w for w in first if w in pool_map]
        missing = [w for w in first if w not in pool_map]
        for word in missing:
            skipped.append(f"kuratiert, aber kein brauchbares 3+3-Stichwort: {word}")
        if curated_only is False:
            ordered += [w for w, _ in sorted(pool, key=lambda p: (len(p[0]), p[1]))
                        if w not in set(ordered)]
        return [(w, pool_map[w]) for w in ordered[:limit]]

    for word, reading in pick(third_two, d_known, len(d_known), curated_only=True):
        add("D", word, rendered(reading, third_tone_surface(reading)), "false",
            "BLCU 现代汉语: 两个上声前后行，前头那个变阳平")
    # Kategorie E steht **nicht** hier, sondern von Hand in
    # pinyin-corpus-manual.tsv. Ein erster Anlauf erzeugte sie über
    # `third_tone_surface`, das die Regel gleichförmig von links anwandte —
    # dieselbe Annahme, die die Implementierung damals traf. Damit hätte der
    # Corpus einen Fehler als Erfolg gemeldet: Bei drei dritten Tönen
    # entscheidet die Verzweigung (双单格 2-2-3 gegen 单双格 3-2-3), und die
    # kann kein Skript aus der Lesung ableiten. Das Review hat es gefunden.
    _ = third_long

    # H: Komposita ohne eigenes Stichwort, deren Teile das Lexikon kennt.
    # Sollwert ist die Verkettung der Teil-Lesungen — die Zerlegung selbst ist
    # das, was hier geprüft wird.
    compounds = [
        ("啤酒杯", ["啤酒", "杯"]), ("咖啡杯", ["咖啡", "杯"]),
        ("苹果树", ["苹果", "树"]), ("图书馆员", ["图书馆", "员"]),
        ("电影票", ["电影", "票"]), ("火车票", ["火车", "票"]),
        ("牛奶瓶", ["牛奶", "瓶"]), ("面包店", ["面包", "店"]),
        ("汉语课", ["汉语", "课"]), ("英语课", ["英语", "课"]),
        ("医生们", ["医生", "们"]), ("老师们", ["老师", "们"]),
        ("蔬菜汤", ["蔬菜", "汤"]), ("鸡蛋汤", ["鸡蛋", "汤"]),
        ("西瓜汁", ["西瓜", "汁"]), ("香蕉皮", ["香蕉", "皮"]),
        ("照片集", ["照片", "集"]), ("邮局门", ["邮局", "门"]),
        ("博物馆门", ["博物馆", "门"]), ("飞机场路", ["飞机场", "路"]),
        ("咖啡店", ["咖啡", "店"]), ("香蕉树", ["香蕉", "树"]),
        ("西瓜皮", ["西瓜", "皮"]), ("牛奶店", ["牛奶", "店"]),
        ("苹果汁", ["苹果", "汁"]), ("鸡蛋皮", ["鸡蛋", "皮"]),
        ("英语书", ["英语", "书"]), ("汉语书", ["汉语", "书"]),
        ("医生室", ["医生", "室"]), ("警察们", ["警察", "们"]),
        ("邮局员", ["邮局", "员"]), ("公园门", ["公园", "门"]),
        ("图书馆门", ["图书馆", "门"]), ("电影院门", ["电影院", "门"]),
        ("手机店", ["手机", "店"]), ("照片墙", ["照片", "墙"]),
        ("护照页", ["护照", "页"]), ("钥匙圈", ["钥匙", "圈"]),
        ("面包片", ["面包", "片"]), ("米饭碗", ["米饭", "碗"]),
        ("咖啡馆", ["咖啡", "馆"]), ("电视机", ["电视", "机"]),
        ("冰箱门", ["冰箱", "门"]), ("报纸堆", ["报纸", "堆"]),
    ]
    for word, parts in compounds:
        if word in readings:
            skipped.append(f"H {word}: ist selbst Stichwort, prüft die Zerlegung nicht")
            continue
        missing = [p for p in parts if p not in readings or p in ambiguous]
        if missing:
            skipped.append(f"H {word}: Teil ohne eindeutige Lesung {missing}")
            continue
        pieces = []
        for part in parts:
            reading = readings[part]
            if not is_clean(part, reading):
                missing.append(part)
                break
            pieces.append(rendered(reading, third_tone_surface(reading)))
        if missing:
            skipped.append(f"H {word}: Teil unbrauchbar {missing}")
            continue
        add("H", word, "".join(pieces), "false",
            "CC-CEDICT Teil-Stichwörter + Zerlegung (A23)")

    # I: Alltagssätze. Verglichen wird leerzeichenunabhängig — Wortabstände
    # sind Orthografie, nicht Aussprache.
    for sentence, words in SENTENCES:
        expected = sentence_reading(sentence, words, readings, ambiguous)
        if expected is None:
            # Ausgelassen, **nicht** nach J umgebucht. Ein erster Anlauf tat
            # das und behauptete damit „muss geprüft werden" für Sätze, bei
            # denen nur *diese* Ableitung scheiterte — die App löst
            # `早上好`, `我住在北京` und `我听不懂` einwandfrei auf. Eine
            # Review-Erwartung braucht eine eigene Begründung, und die steht
            # im Handteil.
            skipped.append(f"I {sentence}: hier nicht ableitbar, kein Sollwert")
            continue
        add("I", sentence, expected, "false",
            "CC-CEDICT + BLCU-Regeln auf handgesetzter Segmentierung")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Pinyin Golden Corpus — datengestützter Teil.",
        "# ERZEUGT von tools/generate-pinyin-corpus.py. Nicht von Hand bearbeiten.",
        "# Die regelkritischen Kategorien stehen in pinyin-corpus-manual.tsv.",
        "#",
        "# Spalten: Kategorie, Hanzi, erwartete Lernaussprache, needsReview, Herkunft",
        "# des Sollwerts. Kategorien hier: A Grundwortschatz, B neutraler Ton,",
        "# C Polyphone im Kontext, D zwei dritte Töne, H Komposita/Zerlegung,",
        "# I Alltagssätze. E, F, G, J und K stehen von Hand in",
        "# pinyin-corpus-manual.tsv.",
    ]
    for row in rows:
        lines.append("\t".join(row))
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    counts: dict[str, int] = {}
    for category, *_ in rows:
        counts[category] = counts.get(category, 0) + 1
    print(f"{OUT.relative_to(ROOT)}: {len(rows)} Fälle")
    for category in sorted(counts):
        print(f"  {category}: {counts[category]}")
    if MANUAL.exists():
        manual = [
            line for line in MANUAL.read_text(encoding="utf-8").splitlines()
            if line and not line.startswith("#")
        ]
        print(f"{MANUAL.relative_to(ROOT)}: {len(manual)} Fälle von Hand")
    if skipped:
        print(f"\n{len(skipped)} übersprungen:")
        for note in skipped:
            print(f"  {note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
