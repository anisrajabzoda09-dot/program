import os
from PIL import Image, ImageDraw, ImageFont

# Page Dimensions (A4 at 150 DPI)
W = 1240
H = 1754
MARGIN_X = 70
MARGIN_Y = 60

# Fonts
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

font_title = ImageFont.truetype(FONT_BOLD, 38)
font_h1 = ImageFont.truetype(FONT_BOLD, 26)
font_h2 = ImageFont.truetype(FONT_BOLD, 20)
font_h3 = ImageFont.truetype(FONT_BOLD, 17)
font_body = ImageFont.truetype(FONT_REG, 15)
font_body_bold = ImageFont.truetype(FONT_BOLD, 15)
font_small = ImageFont.truetype(FONT_REG, 13)
font_small_bold = ImageFont.truetype(FONT_BOLD, 13)
font_tiny = ImageFont.truetype(FONT_REG, 11)
font_tiny_bold = ImageFont.truetype(FONT_BOLD, 11)

# Color Palette
COLOR_BG = (255, 255, 255)
COLOR_TEXT = (15, 23, 42)
COLOR_MUTED = (71, 85, 105)
COLOR_PRIMARY = (79, 70, 229)
COLOR_PRIMARY_LIGHT = (238, 242, 255)
COLOR_SUCCESS = (16, 185, 129)
COLOR_DANGER = (239, 68, 68)
COLOR_WARNING = (245, 158, 11)
COLOR_BORDER = (226, 232, 240)
COLOR_CARD_BG = (248, 250, 252)

def wrap_text(text, font, max_width):
    """Wrap text to fit within max_width pixels"""
    words = text.split(" ")
    lines = []
    current_line = []
    
    # Temporary draw object to measure text width
    dummy = Image.new("RGB", (10, 10))
    draw = ImageDraw.Draw(dummy)
    
    for word in words:
        test_line = " ".join(current_line + [word])
        bbox = draw.textbbox((0, 0), test_line, font=font)
        w = bbox[2] - bbox[0]
        if w <= max_width:
            current_line.append(word)
        else:
            if current_line:
                lines.append(" ".join(current_line))
            current_line = [word]
    if current_line:
        lines.append(" ".join(current_line))
    return lines

def draw_header(draw, page_num, section_title):
    # Header bar
    draw.text((MARGIN_X, MARGIN_Y), "НИГОҲ FAMILY", fill=COLOR_PRIMARY, font=font_h3)
    
    # Right section title
    bbox = draw.textbbox((0, 0), section_title, font=font_small_bold)
    text_w = bbox[2] - bbox[0]
    draw.text((W - MARGIN_X - text_w, MARGIN_Y + 3), section_title, fill=COLOR_MUTED, font=font_small_bold)
    
    # Divider line
    draw.line([(MARGIN_X, MARGIN_Y + 32), (W - MARGIN_X, MARGIN_Y + 32)], fill=COLOR_PRIMARY, width=2)

def draw_footer(draw, page_num, total_pages=6):
    y = H - MARGIN_Y - 15
    draw.line([(MARGIN_X, y), (W - MARGIN_X, y)], fill=COLOR_BORDER, width=1)
    
    text_left = "© 2026 Нигоҳ Family • Муҳофизати Оқилонаи Фарзанд"
    draw.text((MARGIN_X, y + 10), text_left, fill=COLOR_MUTED, font=font_tiny)
    
    text_right = f"Саҳифаи {page_num} аз {total_pages}"
    bbox = draw.textbbox((0, 0), text_right, font=font_tiny_bold)
    text_w = bbox[2] - bbox[0]
    draw.text((W - MARGIN_X - text_w, y + 10), text_right, fill=COLOR_PRIMARY, font=font_tiny_bold)

def create_cover_page():
    img = Image.new("RGB", (W, H), color=COLOR_BG)
    draw = ImageDraw.Draw(img)

    # Top Badge
    badge_text = "МУАРРИФИИ РАСМИИ ЛОИҲА • WHITEPAPER 2026"
    bbox = draw.textbbox((0, 0), badge_text, font=font_small_bold)
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    bx = (W - bw) // 2
    draw.rounded_rectangle([bx - 18, MARGIN_Y + 10, bx + bw + 18, MARGIN_Y + 10 + bh + 14], radius=16, fill=COLOR_PRIMARY_LIGHT, outline=(199, 210, 254), width=1)
    draw.text((bx, MARGIN_Y + 16), badge_text, fill=COLOR_PRIMARY, font=font_small_bold)

    # Big Title
    title = "НИГОҲ FAMILY"
    bbox = draw.textbbox((0, 0), title, font=font_title)
    draw.text(((W - (bbox[2] - bbox[0])) // 2, MARGIN_Y + 70), title, fill=COLOR_TEXT, font=font_title)

    # Subtitle
    sub = "Системаи Комплексии Муҳофизат ва Назорати Оилавии Фарзанд"
    bbox = draw.textbbox((0, 0), sub, font=font_h2)
    draw.text(((W - (bbox[2] - bbox[0])) // 2, MARGIN_Y + 130), sub, fill=COLOR_PRIMARY, font=font_h2)

    # Lead description
    lead = "Технологияи инноватсионии амнияти рақамии кӯдакон дар оилаҳои Тоҷикистон: филтратсияи худкори сайтҳои хатарнок, бастани бозиҳои нолозим ва назорати зиндаи GPS бо дастгирии ҳолати бе интернет (Офлайн)."
    lines = wrap_text(lead, font_body, 980)
    y_lead = MARGIN_Y + 175
    for l in lines:
        bbox = draw.textbbox((0, 0), l, font=font_body)
        draw.text(((W - (bbox[2] - bbox[0])) // 2, y_lead), l, fill=COLOR_MUTED, font=font_body)
        y_lead += 24

    # Hero Image
    hero_path = "pdf/images/hero_family.jpg"
    if os.path.exists(hero_path):
        hero_img = Image.open(hero_path).convert("RGB")
        target_w = 1060
        target_h = int(target_w * (hero_img.height / hero_img.width))
        if target_h > 620:
            target_h = 620
            target_w = int(target_h * (hero_img.width / hero_img.height))
        hero_img = hero_img.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        # Centered
        pos_x = (W - target_w) // 2
        pos_y = y_lead + 30
        
        # Subtle frame
        draw.rounded_rectangle([pos_x - 3, pos_y - 3, pos_x + target_w + 3, pos_y + target_h + 3], radius=16, fill=None, outline=COLOR_BORDER, width=2)
        img.paste(hero_img, (pos_x, pos_y))
        y_after_img = pos_y + target_h + 40
    else:
        y_after_img = y_lead + 400

    # 3 Metadata Boxes
    col_w = (W - 2 * MARGIN_X - 40) // 3
    labels = [
        ("ПЛАТФОРМАҲО", "Android 8.0 — 15+ & Web", "Дастгирии ҳамаи телефонҳо"),
        ("ТЕХНОЛОГИЯИ АСОСӢ", "Python 3.14 + FastAPI", "Бекенди зуд ва амн"),
        ("БАРОРИШИ РАСМИИ APK", "Версияи v2.4.0 (Официалӣ)", "100% санҷидашуда ва тайёр")
    ]
    
    for i, (head, val, desc) in enumerate(labels):
        x = MARGIN_X + i * (col_w + 20)
        draw.rounded_rectangle([x, y_after_img, x + col_w, y_after_img + 130], radius=14, fill=COLOR_CARD_BG, outline=COLOR_BORDER, width=1)
        draw.text((x + 20, y_after_img + 18), head, fill=COLOR_PRIMARY, font=font_tiny_bold)
        draw.text((x + 20, y_after_img + 44), val, fill=COLOR_TEXT, font=font_h3)
        draw.text((x + 20, y_after_img + 84), desc, fill=COLOR_MUTED, font=font_small)

    draw_footer(draw, 1)
    return img

def create_problem_solution_page():
    img = Image.new("RGB", (W, H), color=COLOR_BG)
    draw = ImageDraw.Draw(img)
    draw_header(draw, 2, "Қисми 1: Муаммо ва Ҳалли Он")

    y = MARGIN_Y + 55
    draw.text((MARGIN_X, y), "1. Чаро кӯдакон ба муҳофизати «Нигоҳ» ниёз доранд?", fill=COLOR_TEXT, font=font_h1)
    y += 45

    intro = "Дар замони имрӯза телефонҳои мобилӣ ба дасти ҳар як кӯдаку наврас расидаанд. Бо вуҷуди манфиатҳои омӯзишӣ, истифодаи беназорати смартфон ба хатарҳои ҷиддии равонӣ ва таълимӣ меорад:"
    for l in wrap_text(intro, font_body, W - 2 * MARGIN_X):
        draw.text((MARGIN_X, y), l, fill=COLOR_MUTED, font=font_body)
        y += 24
    y += 15

    # 4 Threat & Solution Cards (2x2)
    card_w = (W - 2 * MARGIN_X - 30) // 2
    card_h = 220

    threats = [
        ("ХАТАРИ №1: САЙТҲОИ НОСОЛИМ", "Сайтҳои зараровар ва фиребгарӣ", 
         "Кӯдакон метавонанд тасодуфан ё аз кунҷковӣ ба сайтҳои дорои мазмуни номуносиб, зӯроварӣ, қиморбозӣ ё доми қаллобони интернетӣ афтанд. Ин ба рӯҳияи онҳо зарбаи сахт мезанад.", COLOR_DANGER),
        
        ("ХАТАРИ №2: ВОБАСТАГИИ БОЗИҲО", "TikTok, Likee, PUBG ва Free Fire",
         "Соатҳои зиёд бо бозиҳои тирандозӣ ва видеоҳои бефосилаи TikTok сарф шуда, хотира суст мешавад ва кӯдак аз мактабу китоб комилан дур мегардад.", COLOR_WARNING),
        
        ("ХАТАРИ №3: ТАШВИШИ ВОЛИДАЙН", "Ноогоҳӣ аз макони писар",
         "Падару модар аксар вақт дар ташвишанд, ки писарашон пас аз мактаб дар куҷост, оё ба дарси иловагӣ расидааст ё бо рафиқони ношинос дар кӯча мебошад.", (2, 132, 199)),
        
        ("ҲАЛЛИ ОҚИЛОНА: НИГОҲ FAMILY", "Муҳити солими рақамӣ дар оила",
         "«Нигоҳ» назорат ва озодии кӯдакро ба эътидол меорад: филтри худкори сайтҳо, бастани бозиҳо дар вақти дарс ва харитаи мустақими GPS барои оромии комили хонавода.", COLOR_SUCCESS)
    ]

    for idx, (badge, title, desc, col) in enumerate(threats):
        row = idx // 2
        col_i = idx % 2
        cx = MARGIN_X + col_i * (card_w + 30)
        cy = y + row * (card_h + 24)

        # Card Box
        draw.rounded_rectangle([cx, cy, cx + card_w, cy + card_h], radius=14, fill=COLOR_CARD_BG, outline=COLOR_BORDER, width=1)
        # Colored Left Accent Bar
        draw.rounded_rectangle([cx, cy, cx + 8, cy + card_h], radius=4, fill=col)

        # Badge
        draw.text((cx + 24, cy + 20), badge, fill=col, font=font_tiny_bold)
        # Title
        draw.text((cx + 24, cy + 45), title, fill=COLOR_TEXT, font=font_h3)
        # Desc
        y_txt = cy + 80
        for l in wrap_text(desc, font_small, card_w - 48):
            draw.text((cx + 24, y_txt), l, fill=COLOR_MUTED, font=font_small)
            y_txt += 22

    y += 2 * card_h + 48 + 20

    # Big Feature Spotlight Box: Offline Mode
    draw.rounded_rectangle([MARGIN_X, y, W - MARGIN_X, y + 250], radius=16, fill=COLOR_PRIMARY_LIGHT, outline=(199, 210, 254), width=1)
    
    draw.text((MARGIN_X + 30, y + 24), "★ БАРТАРИИ БЕНАЗИР: ЧАРО «НИГОҲ» ҲАТТО БЕ ИНТЕРНЕТ КОР МЕКУНАД?", fill=COLOR_PRIMARY, font=font_h3)
    
    offline_p1 = "Дар барномаҳои маъмулии дигар, вақте ки кӯдак интернети телефон (Wi-Fi ё 4G)-ро хомӯш мекунад, барнома кор намекунад ва бозиҳо дубора боз мешаванд."
    y_off = y + 68
    for l in wrap_text(offline_p1, font_body, W - 2 * MARGIN_X - 60):
        draw.text((MARGIN_X + 30, y_off), l, fill=COLOR_TEXT, font=font_body)
        y_off += 24
        
    y_off += 10
    offline_p2 = "Дар лоиҳаи «Нигоҳ» ҳамаи қоидаҳо мустақиман дар хотираи маҳаллии системаи Android ҳифз мешаванд. Ҳатто агар интернет комилан хомӯш бошад ё телефон дар ҳолати парвоз (Airplane mode) қарор гирад, барномаҳои басташуда (TikTok, PUBG) баста мемонанд ва кушода намешаванд!"
    for l in wrap_text(offline_p2, font_body_bold, W - 2 * MARGIN_X - 60):
        draw.text((MARGIN_X + 30, y_off), l, fill=(49, 46, 129), font=font_body_bold)
        y_off += 24

    draw_footer(draw, 2)
    return img

def create_app_blocker_page():
    img = Image.new("RGB", (W, H), color=COLOR_BG)
    draw = ImageDraw.Draw(img)
    draw_header(draw, 3, "Қисми 2: Муҳофизати Барномаҳо ва Safe Web")

    y = MARGIN_Y + 55
    draw.text((MARGIN_X, y), "2. Бастани Барномаҳо (App Blocker) ва Филтри Safe Web", fill=COLOR_TEXT, font=font_h1)
    y += 45

    desc = "Системаи «Нигоҳ» ба волидайн имкон медиҳад, ки бо як тугма бозиҳо ва шабакаҳои иҷтимоиро маҳкам кунанд. Ҳангоми кушодани барномаи басташуда, дар экрани писар паёми расмии маҳдудият пайдо мешавад."
    for l in wrap_text(desc, font_body, W - 2 * MARGIN_X):
        draw.text((MARGIN_X, y), l, fill=COLOR_MUTED, font=font_body)
        y += 24
    y += 15

    # 3D App Blocking Image
    app_img_path = "pdf/images/app_blocking.jpg"
    if os.path.exists(app_img_path):
        app_img = Image.open(app_img_path).convert("RGB")
        target_w = 1000
        target_h = int(target_w * (app_img.height / app_img.width))
        if target_h > 460:
            target_h = 460
            target_w = int(target_h * (app_img.width / app_img.height))
        app_img = app_img.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        pos_x = (W - target_w) // 2
        draw.rounded_rectangle([pos_x - 2, y - 2, pos_x + target_w + 2, y + target_h + 2], radius=14, fill=None, outline=COLOR_BORDER, width=1)
        img.paste(app_img, (pos_x, y))
        y += target_h + 30

    # Table of Apps
    draw.text((MARGIN_X, y), "Рӯйхати барномаҳо ва реҷаи муҳофизати онҳо:", fill=COLOR_TEXT, font=font_h3)
    y += 32

    # Table header
    draw.rectangle([MARGIN_X, y, W - MARGIN_X, y + 42], fill=COLOR_PRIMARY)
    draw.text((MARGIN_X + 20, y + 10), "НОМИ БАРНОМА", fill=(255, 255, 255), font=font_small_bold)
    draw.text((MARGIN_X + 320, y + 10), "НАМУД", fill=(255, 255, 255), font=font_small_bold)
    draw.text((MARGIN_X + 580, y + 10), "ҲОЛАТ", fill=(255, 255, 255), font=font_small_bold)
    draw.text((MARGIN_X + 760, y + 10), "ТАЪСИР ДАР ТЕЛЕФОНИ КӮДАК", fill=(255, 255, 255), font=font_small_bold)
    y += 42

    table_rows = [
        ("TikTok / Likee", "Кӯтоҳвидеоҳо", "Маҳкамшаванда", "Экран фавран баста мешавад ва дастнорас аст", COLOR_DANGER),
        ("PUBG Mobile / Free Fire", "Бозиҳои ҷангӣ", "Маҳкамшаванда", "Бозӣ кушода намешавад, ба дарс машғул мешавад", COLOR_DANGER),
        ("Instagram / Snapchat", "Шабакаҳои иҷтимоӣ", "Маҳкамшаванда", "Пешгирӣ аз зоеъ шудани вақти гаронбаҳо", COLOR_DANGER),
        ("Вебсайтҳои носолим", "Интернети хатарнок", "Филтри худкор", "Маҳдудияти худкор дар сатҳи телефон ва браузер", COLOR_PRIMARY),
        ("Duolingo / Китобҳо", "Омӯзиш ва мактаб", "Ҳамеша кушода", "Барои дарсҳо ва донишандӯзӣ ҳамеша дастрас аст", COLOR_SUCCESS)
    ]

    for i, (name, cat, status, effect, col) in enumerate(table_rows):
        bg = (248, 250, 252) if i % 2 == 1 else (255, 255, 255)
        draw.rectangle([MARGIN_X, y, W - MARGIN_X, y + 46], fill=bg, outline=COLOR_BORDER, width=1)
        draw.text((MARGIN_X + 20, y + 13), name, fill=COLOR_TEXT, font=font_small_bold)
        draw.text((MARGIN_X + 320, y + 13), cat, fill=COLOR_MUTED, font=font_small)
        
        # Pill for status
        draw.rounded_rectangle([MARGIN_X + 575, y + 8, MARGIN_X + 720, y + 36], radius=6, fill=COLOR_PRIMARY_LIGHT if col==COLOR_PRIMARY else ((254, 242, 242) if col==COLOR_DANGER else (240, 253, 244)))
        draw.text((MARGIN_X + 585, y + 12), status, fill=col, font=font_tiny_bold)
        
        draw.text((MARGIN_X + 760, y + 13), effect, fill=COLOR_MUTED, font=font_small)
        y += 46

    y += 25
    # Warning Notification box
    draw.rounded_rectangle([MARGIN_X, y, W - MARGIN_X, y + 100], radius=12, fill=(254, 242, 242), outline=(254, 202, 202), width=1)
    draw.text((MARGIN_X + 24, y + 16), "ПАЁМИ РАСМИЕ, КИ КӮДАК ДАР ЭКРАНИ ТЕЛЕФОН МЕБИНАД:", fill=(185, 28, 28), font=font_small_bold)
    draw.text((MARGIN_X + 24, y + 46), "« [!] Барнома дастнорас аст / Приложение недоступно. Ин барнома аз ҷониби волидайни шумо", fill=(127, 29, 29), font=font_body)
    draw.text((MARGIN_X + 24, y + 70), "муваққатан маҳкам карда шудааст. Маҳдудият ҳатто бе интернет низ фаъол мебошад. »", fill=(127, 29, 29), font=font_body)

    draw_footer(draw, 3)
    return img

def create_gps_page():
    img = Image.new("RGB", (W, H), color=COLOR_BG)
    draw = ImageDraw.Draw(img)
    draw_header(draw, 4, "Қисми 3: Назорати Зиндаи GPS")

    y = MARGIN_Y + 55
    draw.text((MARGIN_X, y), "3. Назорати Зиндаи GPS дар Харитаи Мустақим", fill=COLOR_TEXT, font=font_h1)
    y += 45

    desc = "Ҳамеша огоҳ бошед, ки фарзанди шумо дар куҷост: дар мактаб, дар роҳи ба хона ё дар назди дӯстонаш. «Нигоҳ» макони дақиқро бо истифода аз радифҳои GPS дар харита намоиш медиҳад."
    for l in wrap_text(desc, font_body, W - 2 * MARGIN_X):
        draw.text((MARGIN_X, y), l, fill=COLOR_MUTED, font=font_body)
        y += 24
    y += 15

    # GPS 3D Image
    gps_img_path = "pdf/images/gps_tracker.jpg"
    if os.path.exists(gps_img_path):
        gps_img = Image.open(gps_img_path).convert("RGB")
        target_w = 1000
        target_h = int(target_w * (gps_img.height / gps_img.width))
        if target_h > 490:
            target_h = 490
            target_w = int(target_h * (gps_img.width / gps_img.height))
        gps_img = gps_img.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        pos_x = (W - target_w) // 2
        draw.rounded_rectangle([pos_x - 2, y - 2, pos_x + target_w + 2, y + target_h + 2], radius=14, fill=None, outline=COLOR_BORDER, width=1)
        img.paste(gps_img, (pos_x, y))
        y += target_h + 35

    # 4 GPS Feature Cards
    card_w = (W - 2 * MARGIN_X - 30) // 2
    card_h = 160

    gps_features = [
        ("• КООРДИНАТАҲОИ ДАҚИҚИ ЗИНДА", "Макони фаврӣ дар вақти воқеӣ", 
         "Нишондиҳандаи фаврии ҷойгиршавӣ (Live Marker) дар харита бо суроғаи дақиқи кӯча, маҳалла ва шаҳр.", (14, 165, 233)),
        
        ("• НАЗОРАТИ ЗАРЯДИ БАТАРЕЯ", "Маълумоти вазъи телефон",
         "Волидайн фоизи батареяи телефони писарро мустақиман мебинанд, то кӯдак бе робита ва бе телефон намонад.", COLOR_WARNING),
        
        ("• МИНТАҚАҲОИ БЕХАТАР (МАКТАБ ВА ХОНА)", "Огоҳиномаҳои худкор",
         "Муайян кардани марзҳои мактаб, курсҳои забономӯзӣ ва хона — бо огоҳии худкор ҳангоми расидани кӯдак.", COLOR_PRIMARY),
        
        ("• 100% МАХФИЯТИ ОИЛАВӢ", "Ҳифзи дахлнопазирии маълумот",
         "Координатаҳои макони кӯдак танҳо ба телефони худи волидайн фиристода шуда, ба ҳеҷ ҷойи дигар дода намешаванд.", COLOR_SUCCESS)
    ]

    for idx, (head, title, text, col) in enumerate(gps_features):
        row = idx // 2
        col_i = idx % 2
        cx = MARGIN_X + col_i * (card_w + 30)
        cy = y + row * (card_h + 20)

        draw.rounded_rectangle([cx, cy, cx + card_w, cy + card_h], radius=14, fill=COLOR_CARD_BG, outline=COLOR_BORDER, width=1)
        draw.rounded_rectangle([cx, cy, cx + 6, cy + card_h], radius=3, fill=col)

        draw.text((cx + 22, cy + 18), head, fill=col, font=font_tiny_bold)
        draw.text((cx + 22, cy + 42), title, fill=COLOR_TEXT, font=font_small_bold)
        
        y_t = cy + 76
        for l in wrap_text(text, font_small, card_w - 44):
            draw.text((cx + 22, y_t), l, fill=COLOR_MUTED, font=font_small)
            y_t += 22

    draw_footer(draw, 4)
    return img

def create_qr_pairing_page():
    img = Image.new("RGB", (W, H), color=COLOR_BG)
    draw = ImageDraw.Draw(img)
    draw_header(draw, 5, "Қисми 4: Пайвастшавӣ бо QR-Код")

    y = MARGIN_Y + 55
    draw.text((MARGIN_X, y), "4. Пайвастшавӣ бо QR-Код дар 5 Сония", fill=COLOR_TEXT, font=font_h1)
    y += 45

    desc = "Барои танзим намудани барнома ягон дониши барномасозӣ ё симҳои иловагӣ лозим нест. Ҳамаи раванд бо як сканкунии фаврии QR-код иҷро мешавад."
    for l in wrap_text(desc, font_body, W - 2 * MARGIN_X):
        draw.text((MARGIN_X, y), l, fill=COLOR_MUTED, font=font_body)
        y += 24
    y += 15

    # 3D QR Pairing Image
    qr_img_path = "pdf/images/qr_pairing.jpg"
    if os.path.exists(qr_img_path):
        qr_img = Image.open(qr_img_path).convert("RGB")
        target_w = 1000
        target_h = int(target_w * (qr_img.height / qr_img.width))
        if target_h > 460:
            target_h = 460
            target_w = int(target_h * (qr_img.width / qr_img.height))
        qr_img = qr_img.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        pos_x = (W - target_w) // 2
        draw.rounded_rectangle([pos_x - 2, y - 2, pos_x + target_w + 2, y + target_h + 2], radius=14, fill=None, outline=COLOR_BORDER, width=1)
        img.paste(qr_img, (pos_x, y))
        y += target_h + 35

    # 4 Steps Layout
    draw.text((MARGIN_X, y), "Дастури 4-Қадамаи Пайвастшавӣ:", fill=COLOR_TEXT, font=font_h3)
    y += 30

    steps = [
        ("1", "Бақайдгирӣ дар сайт ва боргирии APK", "Дар сомонаи расмӣ бо Google ё Email сабти ном кунед ва бастаи APK-ро боргирӣ намоед.", COLOR_PRIMARY),
        ("2", "Насби APK дар телефони писар", "Файли барномаро дар телефони кӯдак кушоед ва иҷозати AccessibilityService-ро фаъол кунед.", COLOR_PRIMARY),
        ("3", "Интихоби нақши «Фарзанд» ва намоиши QR-код", "Дар экрани телефони писар QR-коди яккаратаи амн тавлид мешавад.", COLOR_PRIMARY),
        ("4", "Сканкунӣ аз телефони волидайн", "Бо телефони худ QR-кодро скан кунед — телефонҳо фавран пайваст мешаванд ва муҳофизат фаъол мегардад!", COLOR_SUCCESS)
    ]

    steps_w = W - 2 * MARGIN_X - 220
    for num, title, text, col in steps:
        draw.rounded_rectangle([MARGIN_X, y, MARGIN_X + steps_w, y + 84], radius=10, fill=COLOR_CARD_BG, outline=COLOR_BORDER, width=1)
        
        # Number badge
        draw.rounded_rectangle([MARGIN_X + 16, y + 18, MARGIN_X + 64, y + 66], radius=8, fill=col)
        draw.text((MARGIN_X + 33, y + 26), num, fill=(255, 255, 255), font=font_h2)
        
        draw.text((MARGIN_X + 80, y + 16), title, fill=COLOR_TEXT, font=font_small_bold)
        draw.text((MARGIN_X + 80, y + 44), text, fill=COLOR_MUTED, font=font_small)
        
        y += 98

    # QR Code Sample on the right
    sample_qr_path = "pdf/images/sample_qr.png"
    if os.path.exists(sample_qr_path):
        sqr = Image.open(sample_qr_path).convert("RGB")
        sqr = sqr.resize((190, 190), Image.Resampling.LANCZOS)
        qr_x = W - MARGIN_X - 190
        qr_y = y - 4 * 98 + 40
        draw.rounded_rectangle([qr_x - 12, qr_y - 12, qr_x + 202, qr_y + 242], radius=14, fill=COLOR_CARD_BG, outline=COLOR_BORDER, width=1)
        img.paste(sqr, (qr_x, qr_y))
        draw.text((qr_x + 10, qr_y + 204), "Намунаи рамзи QR", fill=COLOR_MUTED, font=font_tiny_bold)

    draw_footer(draw, 5)
    return img

def create_architecture_reviews_page():
    img = Image.new("RGB", (W, H), color=COLOR_BG)
    draw = ImageDraw.Draw(img)
    draw_header(draw, 6, "Қисми 5: Мушаххасоти Техникӣ ва Хулоса")

    y = MARGIN_Y + 55
    draw.text((MARGIN_X, y), "5. Архитектураи Техникӣ ва Тақризҳои Волидайн", fill=COLOR_TEXT, font=font_h1)
    y += 45

    # Tech Architecture Table
    draw.rectangle([MARGIN_X, y, W - MARGIN_X, y + 42], fill=COLOR_PRIMARY)
    draw.text((MARGIN_X + 20, y + 10), "ҚИСМИ СИСТЕМА", fill=(255, 255, 255), font=font_small_bold)
    draw.text((MARGIN_X + 380, y + 10), "ТЕХНОЛОГИЯҲО ВА БАРТАРИҲО", fill=(255, 255, 255), font=font_small_bold)
    y += 42

    arch_rows = [
        ("Бекенд (FastAPI)", "Python 3.14 + FastAPI — баландсуръат, устувор, ҳифзи сессияҳои волидайн ва Google OAuth"),
        ("Пойгоҳи додаҳо", "SQLite — зудкор, амн ва сабук бидуни зарурати серверҳои мураккаб"),
        ("Вебсайти расмӣ", "Modern Tech SaaS UI — намоиши телефони зинда, бақайдгирӣ бо Google ва боргирии APK"),
        ("Барномаи мобилӣ", "Android 8.0 то 15+ (ARM64 & x86_64). Ҳаҷм: 42.8 MB, сарфакори энергияи батарея"),
        ("Муҳофизати офлайн", "AccessibilityService + DeviceAdmin + Local Storage — кори 100% бе интернет")
    ]

    for i, (part, desc) in enumerate(arch_rows):
        bg = (248, 250, 252) if i % 2 == 1 else (255, 255, 255)
        draw.rectangle([MARGIN_X, y, W - MARGIN_X, y + 50], fill=bg, outline=COLOR_BORDER, width=1)
        draw.text((MARGIN_X + 20, y + 15), part, fill=COLOR_TEXT, font=font_small_bold)
        for idx_l, l in enumerate(wrap_text(desc, font_small, W - MARGIN_X - 420)):
            draw.text((MARGIN_X + 380, y + 8 + idx_l * 20), l, fill=COLOR_MUTED, font=font_small)
        y += 50

    y += 40

    # Reviews Section
    draw.text((MARGIN_X, y), "Фикру Мулоҳизаҳои Воқеии Волидайни Тоҷикистон:", fill=COLOR_TEXT, font=font_h3)
    y += 32

    reviews = [
        ("«Барномаи беҳтарин! Писарам ҳар рӯз соатҳо дар TikTok ва бозиҳои бефосила буд ва дарсҳояшро тарк мекард. Бо «Нигоҳ» ман ҳамаашро бастам. Муҳимтар аз ҳама, агар интернетро хомӯш кунад ҳам, бозиҳо маҳкам мемонанд!»",
         "★ ★ ★ ★ ★  Ҷамшед Раҳимов • Падари писари 12-сола (ш. Душанбе)"),
        
        ("«Макони писарамро ҳамеша дар харитаи мустақим мебинам. Акнун хавотир намешавам, ки пас аз мактаб ба куҷо меравад ва оё саломат аст ё не. Раҳмати калон барои ин барномаи муҳим!»",
         "★ ★ ★ ★ ★  Нигина Сатторова • Модари 2 фарзанд (ш. Хуҷанд)")
    ]

    card_w = (W - 2 * MARGIN_X - 30) // 2
    for idx, (quote, author) in enumerate(reviews):
        cx = MARGIN_X + idx * (card_w + 30)
        draw.rounded_rectangle([cx, y, cx + card_w, y + 190], radius=14, fill=COLOR_CARD_BG, outline=COLOR_BORDER, width=1)
        
        y_q = y + 20
        for l in wrap_text(quote, font_small, card_w - 40):
            draw.text((cx + 20, y_q), l, fill=COLOR_TEXT, font=font_small)
            y_q += 22
            
        draw.line([(cx + 20, y + 135), (cx + card_w - 20, y + 135)], fill=COLOR_BORDER, width=1)
        draw.text((cx + 20, y + 150), author, fill=COLOR_PRIMARY, font=font_tiny_bold)

    y += 230

    # Final CTA Banner
    draw.rounded_rectangle([MARGIN_X, y, W - MARGIN_X, y + 170], radius=18, fill=(15, 23, 42))
    draw.text((MARGIN_X + 40, y + 28), "Ҳозир сабти ном кунед ва барномаи Android-ро боргирӣ намоед!", fill=(255, 255, 255), font=font_h2)
    draw.text((MARGIN_X + 40, y + 72), "Сомонаи расмӣ барои боргирӣ ва бақайдгирӣ: http://127.0.0.1:8080", fill=(56, 189, 248), font=font_body_bold)
    draw.text((MARGIN_X + 40, y + 112), "Бастаи расмии Android APK (v2.4.0) омодаи насб дар телефон мебошад.", fill=(203, 213, 225), font=font_small)

    draw_footer(draw, 6)
    return img

def main():
    print("Сохтани саҳифаҳои муаррифии расмии Нигоҳ Family...")
    
    p1 = create_cover_page()
    p1.save("pdf/page_1.png")
    print("Саҳифаи 1 таёр шуд (Cover Page).")

    p2 = create_problem_solution_page()
    p2.save("pdf/page_2.png")
    print("Саҳифаи 2 таёр шуд (Problem & Solution).")

    p3 = create_app_blocker_page()
    p3.save("pdf/page_3.png")
    print("Саҳифаи 3 таёр шуд (App Blocker & Safe Web).")

    p4 = create_gps_page()
    p4.save("pdf/page_4.png")
    print("Саҳифаи 4 таёр шуд (GPS Tracking).")

    p5 = create_qr_pairing_page()
    p5.save("pdf/page_5.png")
    print("Саҳифаи 5 таёр шуд (QR Pairing).")

    p6 = create_architecture_reviews_page()
    p6.save("pdf/page_6.png")
    print("Саҳифаи 6 таёр шуд (Architecture & Reviews).")

    # Generate PDF
    pdf_path = "pdf/Nigoh_Family_Presentation.pdf"
    p1.save(pdf_path, save_all=True, append_images=[p2, p3, p4, p5, p6], resolution=150.0)
    print(f"\n🎉 Файли PDF бо муваффақият сохта шуд: {pdf_path}")
    print(f"Ҳаҷми файл: {os.path.getsize(pdf_path) / (1024*1024):.2f} MB")

if __name__ == "__main__":
    main()
