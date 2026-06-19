import Foundation

enum EmojiShortcodes {
    static let map: [String: String] = parse(raw)

    private static func parse(_ s: String) -> [String: String] {
        var d: [String: String] = [:]
        for pair in s.split(separator: " ") {
            let parts = pair.split(separator: ":", maxSplits: 1)
            if parts.count == 2 { d[String(parts[0])] = String(parts[1]) }
        }
        return d
    }

    private static let raw = """
+1:👍 -1:👎 100:💯 1234:🔢 \
smile:😄 grin:😁 joy:😂 rofl:🤣 sob:😭 cry:😢 disappointed:😞 \
worried:😟 confused:😕 astonished:😲 flushed:😳 fearful:😨 \
blush:😊 wink:😉 heart_eyes:😍 kissing_heart:😘 kissing:😗 \
stuck_out_tongue:😛 stuck_out_tongue_winking_eye:😜 \
sweat_smile:😅 laughing:😆 satisfied:😆 innocent:😇 \
sunglasses:😎 nerd_face:🤓 face_with_monocle:🧐 \
thinking:🤔 neutral_face:😐 expressionless:😑 smirk:😏 \
unamused:😒 pensive:😔 sleepy:😪 tired_face:😫 weary:😩 \
triumph:😤 rage:😡 angry:😠 skull:💀 skull_and_crossbones:☠️ \
ghost:👻 alien:👽 robot:🤖 pile_of_poo:💩 poop:💩 \
upside_down_face:🙃 money_mouth_face:🤑 hugs:🤗 \
zipper_mouth_face:🤐 shushing_face:🤫 lying_face:🤥 \
mask:😷 thermometer_face:🤒 hot_face:🥵 cold_face:🥶 \
star_struck:🤩 partying_face:🥳 exploding_head:🤯 \
dizzy_face:😵 anguished:😧 confounded:😖 persevere:😣 \
open_mouth:😮 hushed:😯 frowning:😦 agonized:😫 \
yawning_face:🥱 monocle_face:🧐 \
wave:👋 clap:👏 raised_hands:🙌 pray:🙏 muscle:💪 \
ok_hand:👌 point_up:☝️ point_up_2:👆 point_down:👇 \
point_left:👈 point_right:👉 fu:🖕 v:✌️ \
crossed_fingers:🤞 hand:✋ open_hands:👐 handshake:🤝 \
writing_hand:✍️ nail_care:💅 ear:👂 eye:👁️ nose:👃 \
lips:👄 tongue:👅 brain:🧠 tooth:🦷 foot:🦶 leg:🦵 \
fist:✊ raised_fist:✊ left_facing_fist:🤛 right_facing_fist:🤜 \
thumbsup:👍 thumbsdown:👎 index_pointing_at_the_viewer:🫵 \
hand_with_index_finger_and_thumb_crossed:🫰 \
heart:❤️ blue_heart:💙 green_heart:💚 purple_heart:💜 \
yellow_heart:💛 orange_heart:🧡 brown_heart:🤎 \
black_heart:🖤 white_heart:🤍 broken_heart:💔 \
sparkling_heart:💖 two_hearts:💕 revolving_hearts:💞 \
heartbeat:💓 heartpulse:💗 mending_heart:❤️‍🩹 \
heart_on_fire:❤️‍🔥 heart_exclamation:❣️ cupid:💘 \
gift_heart:💝 heart_decoration:💟 \
fire:🔥 tada:🎉 rocket:🚀 star:⭐ star2:🌟 sparkles:✨ \
zap:⚡ boom:💥 white_check_mark:✅ x:❌ warning:⚠️ \
bulb:💡 bell:🔔 no_bell:🔕 lock:🔒 unlock:🔓 key:🔑 \
gear:⚙️ hammer:🔨 wrench:🔧 nut_and_bolt:🔩 \
computer:💻 phone:📱 telephone:☎️ email:📧 calendar:📅 \
clock:🕐 hourglass:⌛ hourglass_flowing_sand:⏳ \
money_with_wings:💸 gift:🎁 balloon:🎈 camera:📷 \
pencil:✏️ pen:🖊️ paperclip:📎 link:🔗 scissors:✂️ \
trash:🗑️ folder:📁 open_file_folder:📂 \
chart_increasing:📈 chart_decreasing:📉 bar_chart:📊 \
magnifying_glass_tilted_left:🔍 magnifying_glass_tilted_right:🔎 \
shopping_cart:🛒 credit_card:💳 dollar:💵 yen:💴 \
euro:💶 pound:💷 gem:💎 crown:👑 trophy:🏆 \
medal_sports:🏅 ticket:🎫 label:🏷️ bookmark:🔖 \
eyes:👀 speech_balloon:💬 thought_balloon:💭 zzz:💤 \
sos:🆘 no_entry:⛔ no_entry_sign:🚫 recycle:♻️ \
infinity:♾️ heavy_check_mark:✔️ heavy_plus_sign:➕ \
heavy_minus_sign:➖ heavy_division_sign:➗ asterisk:*️⃣ \
wavy_dash:〰️ new:🆕 free:🆓 up:🆙 cool:🆒 ng:🆖 \
ok:🆗 end:🔚 back:🔙 soon:🔜 top:🔝 \
abc:🔤 ab:🆎 cl:🆑 vs:🆚 atm:🏧 \
sunny:☀️ cloud:☁️ rainbow:🌈 snowflake:❄️ snowman:⛄ \
umbrella:☂️ tornado:🌪️ fog:🌫️ crescent_moon:🌙 \
full_moon:🌕 new_moon:🌑 shooting_star:🌠 comet:☄️ \
earth_americas:🌎 earth_asia:🌏 earth_africa:🌍 \
globe_with_meridians:🌐 world_map:🗺️ \
dog:🐶 cat:🐱 fox_face:🦊 bird:🐦 fish:🐟 \
butterfly:🦋 bee:🐝 bug:🐛 spider:🕷️ crab:🦀 \
turtle:🐢 snake:🐍 dragon:🐉 dinosaur:🦕 t-rex:🦖 \
whale:🐳 dolphin:🐬 elephant:🐘 lion:🦁 tiger:🐯 \
bear:🐻 panda_face:🐼 koala:🐨 rabbit:🐰 mouse:🐭 \
hamster:🐹 squirrel:🐿️ chicken:🐔 penguin:🐧 owl:🦉 \
deer:🦌 horse:🐴 pig:🐷 cow:🐮 sheep:🐑 goat:🐐 \
camel:🐪 giraffe:🦒 zebra:🦓 gorilla:🦍 monkey_face:🐵 \
monkey:🐒 octopus:🐙 lobster:🦞 coral:🪸 \
potted_plant:🪴 four_leaf_clover:🍀 palm_tree:🌴 \
evergreen_tree:🌲 deciduous_tree:🌳 mushroom:🍄 rose:🌹 \
tulip:🌷 sunflower:🌻 blossom:🌸 cherry_blossom:🌸 \
bouquet:💐 seedling:🌱 herb:🌿 \
coffee:☕ beer:🍺 wine_glass:🍷 cocktail:🍸 \
champagne:🍾 tea:🍵 milk_glass:🥛 juice_box:🧃 \
pizza:🍕 hamburger:🍔 taco:🌮 burrito:🌯 \
sandwich:🥪 hot_dog:🌭 fries:🍟 popcorn:🍿 \
cake:🎂 cupcake:🧁 ice_cream:🍦 chocolate_bar:🍫 \
candy:🍬 lollipop:🍭 cookie:🍪 doughnut:🍩 \
waffle:🧇 pancakes:🥞 apple:🍎 banana:🍌 \
grapes:🍇 strawberry:🍓 watermelon:🍉 peach:🍑 \
mango:🥭 pineapple:🍍 coconut:🥥 avocado:🥑 \
tomato:🍅 eggplant:🍆 carrot:🥕 corn:🌽 \
hot_pepper:🌶️ broccoli:🥦 salad:🥗 sushi:🍣 \
ramen:🍜 noodle:🍝 rice:🍚 bread:🍞 cheese:🧀 \
egg:🥚 bacon:🥓 meat_on_bone:🍖 poultry_leg:🍗 \
soccer:⚽ basketball:🏀 football:🏈 baseball:⚾ \
tennis:🎾 volleyball:🏐 rugby_football:🏉 \
flying_disc:🥏 golf:⛳ dart:🎯 bowling:🎳 \
video_game:🎮 chess_pawn:♟️ car:🚗 racing_car:🏎️ \
bus:🚌 truck:🚚 train:🚆 airplane:✈️ \
ship:🚢 sailboat:⛵ bike:🚴 motorcycle:🏍️ \
kick_scooter:🛴 skateboard:🛹 camping:🏕️ tent:⛺ \
mountain:⛰️ beach_umbrella:⛱️ statue_of_liberty:🗽 \
moyai:🗿 japan:🗾 construction:🚧 \
checkered_flag:🏁 flag_us:🇺🇸 flag_gb:🇬🇧 flag_jp:🇯🇵 \
flag_de:🇩🇪 flag_fr:🇫🇷 flag_ca:🇨🇦 flag_au:🇦🇺 \
flag_in:🇮🇳 flag_cn:🇨🇳 flag_br:🇧🇷 flag_ru:🇷🇺 \
flag_mx:🇲🇽 flag_es:🇪🇸 flag_it:🇮🇹 flag_kr:🇰🇷 \
flag_sg:🇸🇬 flag_ng:🇳🇬 flag_za:🇿🇦 flag_eg:🇪🇬 \
flag_ar:🇦🇷 flag_pk:🇵🇰 us:🇺🇸 gb:🇬🇧 jp:🇯🇵 \
de:🇩🇪 fr:🇫🇷 ca:🇨🇦 au:🇦🇺 cn:🇨🇳 br:🇧🇷 \
ru:🇷🇺 mx:🇲🇽 es:🇪🇸 it:🇮🇹 kr:🇰🇷 in:🇮🇳
"""
}
