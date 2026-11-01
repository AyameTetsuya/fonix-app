"""Build the versioned, bundled curriculum. No network or proprietary material.

Definitions and Japanese explanations are original draft teaching material.
Audio and phonetic content still require the review described in requirements.md.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOUNDS = [
    ('s','s','s','したを はの うしろに。すきまから いきを だそう。','sat','s'),
    ('a','a','æ','くちを よこに ひらいて、あごを さげよう。','cat','a'),
    ('t','t','t','したを はの うしろに つけて、はなそう。','tap','t'),
    ('p','p','p','くちびるを とじて、いきを ぱっと だそう。','pin','p'),
    ('i','i','ɪ','くちを すこし ひらいて、みじかく こえを だそう。','sit','I'),
    ('n','n','n','したを うえの はの うしろに。はなへ こえを ぬこう。','nap','n'),
    ('m','m','m','くちびるを とじて、はなに こえを ひびかせよう。','map','m'),
    ('d','d','d','したを はの うしろに つけて、こえと いっしょに はなそう。','dog','d'),
    ('g','g','ɡ','したの おくを あげて、こえを だして はなそう。','gap','g'),
    ('o','o','ɑ','くちを ひらいて、したを ひくくしよう。','pot','A:'),
    ('c','c','k','この しまの c は、したの おくで いきを とめて はなすよ。','cat','k'),
    ('k','k','k','したの おくで いきを とめて、ぱっと はなそう。','kit','k'),
    ('e','e','ɛ','くちを すこし よこに ひらこう。','bed','E'),
    ('u','u','ʌ','くちも したも ちからを ぬいて、みじかく。','cup','V'),
    ('b','b','b','くちびるを とじて、こえと いっしょに はなそう。','bat','b'),
    ('h','h','h','くちを ひらいて、やさしく いきを だそう。','hat','h'),
    ('f','f','f','うえの はを したくちびるに そっと あてて、いきを だそう。','fan','f'),
    ('l','l','l','したの さきを うえの はの うしろに つけよう。','leg','l'),
    ('r','r','ɹ','したを くちの なかで もちあげるよ。うえに つけないでね。','red','r'),
    ('j','j','dʒ','したで いきを とめてから、こえを だして はなそう。','jam','dZ'),
    ('v','v','v','うえの はを したくちびるに。こえを ひびかせよう。','van','v'),
    ('w','w','w','くちびるを まるくして、つぎの おとへ うごかそう。','wet','w'),
    ('y','y','j','したを うえに ちかづけて、つぎの おとへ うごかそう。','yes','j'),
    ('z','z','z','s と おなじ くちで、こえを ひびかせよう。','zip','z'),
    ('x','x','ks','k と s の ふたつの おとを つなげよう。','box','ks'),
    ('qu','qu','kw','k と w の おとを つなげよう。','quit','kw'),
    ('sh','sh','ʃ','くちびるを すこし まるく。いきを だそう。','ship','S'),
    ('ch','ch','tʃ','いきを とめてから、くちびるを まるくして はなそう。','chip','tS'),
    ('th','th','θ','したの さきを はの あいだに そっと。いきを だそう。','thin','T'),
    ('thv','th','ð','したの さきを はの あいだに。こえを ひびかせよう。','this','D'),
    ('ng','ng','ŋ','したの おくを あげて、はなに こえを ひびかせよう。','ring','N'),
    ('ck','ck','k','ふたつの もじで k の おと。さいごに みつけてね。','duck','k'),
    ('st','st','st','s から t へ。あいだに べつの おとを いれず つなげよう。','stop','st'),
    ('sp','sp','sp','s から p へ、つづけて だしてみよう。','spot','sp'),
    ('bl','bl','bl','b の あと、したを つけて l へ つなごう。','black','bl'),
    ('pl','pl','pl','p の あと、したを つけて l へ つなごう。','plan','pl'),
    ('nd','nd','nd','n の あとに d。さいごの おとまで いしきしよう。','sand','nd'),
    ('nt','nt','nt','n の あとに t。お手本を よく きいてね。','tent','nt'),
    ('a_e','a_e','eɪ','くちを ひらいた おとから、すこし とじる おとへ。','cake','eI'),
    ('i_e','i_e','aɪ','くちを ひらいてから、すこし とじていこう。','kite','aI'),
    ('o_e','o_e','oʊ','くちを すこし まるくして、うごかそう。','home','oU'),
    ('u_e','u_e','ju','cute の おと。くちを まるくしていくよ。tube では ちがう よみもあるよ。','cute','ju:'),
    ('ai','ai','eɪ','a_e と おなじ おと。こんどは ai の もじだよ。','rain','eI'),
    ('ay','ay','eɪ','ことばの おわりで よく つかう おとだよ。','day','eI'),
    ('ee','ee','i','くちを よこに ひらいて、したを うえに。','see','i:'),
    ('ea','ea','i','この しまの ea は ee と おなじ おとだよ。','sea','i:'),
    ('oa','oa','oʊ','o_e と おなじ おと。くちを うごかそう。','boat','oU'),
    ('ow','ow','oʊ','この しまの ow は low の おと。cow は べつの よみだよ。','low','oU'),
]

ROWS = '''
sat|sæt|すわった
pat|pæt|やさしく たたく
tap|tæp|かるく たたく
sit|sɪt|すわる
pin|pɪn|ピン
tin|tɪn|かん
tan|tæn|うすい ちゃいろ
pan|pæn|フライパン
nap|næp|ひるね
pit|pɪt|あな
tip|tɪp|さき
sap|sæp|きの しる
nip|nɪp|かるく かむ
mat|mæt|マット
man|mæn|おとこのひと
map|mæp|ちず
mop|mɑp|モップ
mom|mɑm|おかあさん
mad|mæd|おこった
dim|dɪm|うすぐらい
dam|dæm|ダム
dip|dɪp|すこし つける
dig|dɪɡ|ほる
dot|dɑt|てん
dog|dɑɡ|いぬ
got|ɡɑt|てにいれた
tag|tæɡ|ふだ
nag|næɡ|くりかえし いう
gap|ɡæp|すきま
gas|ɡæs|ガス
cog|kɑɡ|はぐるま
cod|kɑd|たら
cot|kɑt|ちいさな ベッド
cop|kɑp|おまわりさん
cap|kæp|ぼうし
can|kæn|かん
cat|kæt|ねこ
kid|kɪd|こども
kit|kɪt|どうぐの セット
pig|pɪɡ|ぶた
pot|pɑt|なべ
pop|pɑp|ぽんと はじける
top|tɑp|いちばん うえ
not|nɑt|ちがう
nod|nɑd|うなずく
bed|bɛd|ベッド
beg|bɛɡ|おねがいする
bet|bɛt|かける
bit|bɪt|すこし
bin|bɪn|いれもの
big|bɪɡ|おおきい
bat|bæt|こうもり
bag|bæɡ|かばん
bun|bʌn|まるい パン
bus|bʌs|バス
bug|bʌɡ|むし
bud|bʌd|つぼみ
but|bʌt|でも
cut|kʌt|きる
cup|kʌp|カップ
cub|kʌb|どうぶつの こども
dad|dæd|おとうさん
den|dɛn|すみか
dug|dʌɡ|ほった
fed|fɛd|たべさせた
fit|fɪt|ぴったり あう
fin|fɪn|ひれ
fat|fæt|あぶら
fan|fæn|せんぷうき
fog|fɑɡ|きり
fun|fʌn|たのしい
fig|fɪɡ|いちじく
leg|lɛɡ|あし
let|lɛt|させる
lit|lɪt|あかりが ついた
log|lɑɡ|まるた
lot|lɑt|たくさん
lap|læp|ひざ
lip|lɪp|くちびる
lid|lɪd|ふた
lad|læd|おとこのこ
lug|lʌɡ|おもいものを はこぶ
gum|ɡʌm|ガム
hat|hæt|ぼうし
hen|hɛn|めんどり
hop|hɑp|ぴょんと とぶ
hot|hɑt|あつい
hut|hʌt|こや
red|ɹɛd|あか
rid|ɹɪd|とりのぞく
rag|ɹæɡ|ぬの
rat|ɹæt|ねずみ
ram|ɹæm|おすの ひつじ
rim|ɹɪm|ふち
rip|ɹɪp|やぶる
run|ɹʌn|はしる
rug|ɹʌɡ|じゅうたん
rub|ɹʌb|こする
rib|ɹɪb|あばらぼね
rob|ɹɑb|うばう
jam|dʒæm|ジャム
jet|dʒɛt|ジェットき
jig|dʒɪɡ|かるい ダンス
jog|dʒɑɡ|ゆっくり はしる
jug|dʒʌɡ|みずさし
job|dʒɑb|しごと
van|væn|ワゴンしゃ
vet|vɛt|どうぶつの おいしゃさん
vat|væt|おおきな おけ
wag|wæɡ|しっぽを ふる
web|wɛb|くもの す
wet|wɛt|ぬれた
wig|wɪɡ|かつら
win|wɪn|かつ
wit|wɪt|きの きく こと
yak|jæk|ヤク
yam|jæm|いもの なかま
yap|jæp|いぬが ほえる
yet|jɛt|まだ
yes|jɛs|はい
zip|zɪp|ファスナーを しめる
zap|zæp|すばやく うごく
box|bɑks|はこ
fox|fɑks|きつね
six|sɪks|ろく
fix|fɪks|なおす
mix|mɪks|まぜる
wax|wæks|ろう
tax|tæks|ぜいきん
quit|kwɪt|やめる
quiz|kwɪz|クイズ
quip|kwɪp|きのきいた ことば
ship|ʃɪp|ふね
shop|ʃɑp|おみせ
shin|ʃɪn|すね
shot|ʃɑt|なげた たま
shut|ʃʌt|しめる
fish|fɪʃ|さかな
wish|wɪʃ|ねがう
dish|dɪʃ|おさら
cash|kæʃ|おかね
mash|mæʃ|つぶす
rush|ɹʌʃ|いそぐ
hush|hʌʃ|しずかにする
rash|ɹæʃ|はっしん
lush|lʌʃ|みどりが ゆたか
chin|tʃɪn|あご
chip|tʃɪp|ちいさな かけら
chop|tʃɑp|きざむ
chat|tʃæt|おしゃべり
much|mʌtʃ|たくさん
such|sʌtʃ|そのような
rich|ɹɪtʃ|ゆたかな
thin|θɪn|うすい
thud|θʌd|どすん という おと
moth|mɑθ|が
math|mæθ|さんすう
bath|bæθ|おふろ
path|pæθ|こみち
this|ðɪs|これ
that|ðæt|あれ
them|ðɛm|かれらを
then|ðɛn|そのとき
than|ðæn|よりも
sing|sɪŋ|うたう
song|sɑŋ|うた
sang|sæŋ|うたった
ring|ɹɪŋ|ゆびわ
rang|ɹæŋ|なった
king|kɪŋ|おうさま
wing|wɪŋ|つばさ
bang|bæŋ|ばん という おと
hang|hæŋ|つるす
neck|nɛk|くび
peck|pɛk|くちばしで つつく
pick|pɪk|えらぶ
pack|pæk|にもつを つめる
sack|sæk|ふくろ
sick|sɪk|ぐあいが わるい
sock|sɑk|くつした
rock|ɹɑk|いわ
rack|ɹæk|たな
duck|dʌk|あひる
luck|lʌk|こううん
lock|lɑk|かぎ
kick|kɪk|ける
back|bæk|うしろ
quick|kwɪk|はやい
stop|stɑp|とまる
step|stɛp|いっぽ
spot|spɑt|てん
spin|spɪn|まわる
spit|spɪt|はきだす
snap|snæp|ぱちんと ならす
snip|snɪp|ちょきんと きる
slim|slɪm|ほそい
slip|slɪp|すべる
slot|slɑt|ほそい あな
slam|slæm|ばたんと しめる
flat|flæt|たいら
flag|flæɡ|はた
flop|flɑp|ばたっと たおれる
flip|flɪp|ひっくりかえす
plan|plæn|けいかく
plug|plʌɡ|せん
plum|plʌm|すもも
clap|klæp|はくしゅ
clip|klɪp|クリップ
club|klʌb|クラブ
crab|kɹæb|かに
grab|ɡɹæb|つかむ
drip|dɹɪp|しずくが おちる
drop|dɹɑp|おとす
drag|dɹæɡ|ひきずる
frog|fɹɑɡ|かえる
grin|ɡɹɪn|にっこり わらう
grip|ɡɹɪp|にぎる
trip|tɹɪp|たび
trap|tɹæp|わな
trim|tɹɪm|きりそろえる
tent|tɛnt|テント
bent|bɛnt|まがった
sent|sɛnt|おくった
went|wɛnt|いった
sand|sænd|すな
hand|hænd|て
land|lænd|りく
pond|pɑnd|いけ
end|ɛnd|おわり
bend|bɛnd|まげる
band|bænd|バンド
lamp|læmp|ランプ
jump|dʒʌmp|ジャンプ
bump|bʌmp|こぶ
pump|pʌmp|ポンプ
limp|lɪmp|あしを ひきずる
black|blæk|くろ
cake|keɪk|ケーキ
cape|keɪp|マント
cane|keɪn|つえ
tape|teɪp|テープ
lake|leɪk|みずうみ
late|leɪt|おそい
lane|leɪn|ほそい みち
name|neɪm|なまえ
game|ɡeɪm|ゲーム
same|seɪm|おなじ
safe|seɪf|あんぜん
make|meɪk|つくる
take|teɪk|もっていく
bake|beɪk|やく
rake|ɹeɪk|くまで
rate|ɹeɪt|わりあい
gate|ɡeɪt|もん
hate|heɪt|きらう
made|meɪd|つくった
kite|kaɪt|たこ
bike|baɪk|じてんしゃ
bite|baɪt|かむ
time|taɪm|じかん
lime|laɪm|ライム
line|laɪn|せん
fine|faɪn|げんき
mine|maɪn|わたしのもの
nine|naɪn|きゅう
pine|paɪn|まつ
pipe|paɪp|パイプ
ripe|ɹaɪp|じゅくした
ride|ɹaɪd|のる
side|saɪd|よこ
wide|waɪd|ひろい
hide|haɪd|かくれる
tide|taɪd|しお
hope|hoʊp|きぼう
rope|ɹoʊp|ロープ
home|hoʊm|いえ
bone|boʊn|ほね
cone|koʊn|えんすい
note|noʊt|メモ
vote|voʊt|とうひょう
mole|moʊl|もぐら
hole|hoʊl|あな
pole|poʊl|ぼう
sole|soʊl|あしの うら
cube|kjub|りっぽうたい
cute|kjut|かわいい
mute|mjut|おとを けす
tube|tub|くだ
tune|tun|きょく
flute|flut|フルート
rude|ɹud|しつれいな
rule|ɹul|ルール
rain|ɹeɪn|あめ
mail|meɪl|てがみ
main|meɪn|おもな
pain|peɪn|いたみ
tail|teɪl|しっぽ
sail|seɪl|ほ
nail|neɪl|くぎ
rail|ɹeɪl|レール
paid|peɪd|はらった
wait|weɪt|まつ
bait|beɪt|えさ
gain|ɡeɪn|える
train|tɹeɪn|でんしゃ
brain|bɹeɪn|のう
plain|pleɪn|へいげん
snail|sneɪl|かたつむり
day|deɪ|ひ
hay|heɪ|ほしくさ
bay|beɪ|いりえ
lay|leɪ|よこにする
may|meɪ|してもよい
pay|peɪ|はらう
ray|ɹeɪ|ひかり
say|seɪ|いう
way|weɪ|みち
jay|dʒeɪ|かけす
play|pleɪ|あそぶ
tray|tɹeɪ|おぼん
stay|steɪ|とどまる
see|si|みる
bee|bi|はち
fee|fi|りょうきん
free|fɹi|じゆう
tree|tɹi|き
green|ɡɹin|みどり
queen|kwin|じょおう
need|nid|ひつよう
reef|ɹif|さんごしょう
feed|fid|たべさせる
seed|sid|たね
weed|wid|ざっそう
week|wik|しゅう
deep|dip|ふかい
keep|kip|もっておく
peek|pik|のぞく
meet|mit|あう
feet|fit|りょうあし
feel|fil|かんじる
peel|pil|かわを むく
heel|hil|かかと
seem|sim|のように みえる
seen|sin|みた
keen|kin|ねっしんな
teen|tin|じゅうだい
sea|si|うみ
tea|ti|おちゃ
pea|pi|まめ
leaf|lif|はっぱ
seat|sit|せき
meat|mit|にく
heat|hit|ねつ
beat|bit|リズム
neat|nit|きちんとした
team|tim|チーム
beam|bim|ひかりの すじ
seam|sim|ぬいめ
dream|dɹim|ゆめ
steam|stim|ゆげ
eat|it|たべる
boat|boʊt|ふね
coat|koʊt|コート
goat|ɡoʊt|やぎ
moat|moʊt|ほり
road|ɹoʊd|どうろ
toad|toʊd|ひきがえる
load|loʊd|にもつ
soap|soʊp|せっけん
foam|foʊm|あわ
roam|ɹoʊm|あるきまわる
goal|ɡoʊl|ゴール
coal|koʊl|せきたん
loan|loʊn|かすこと
loaf|loʊf|かたまりの パン
oak|oʊk|かしのき
row|ɹoʊ|こぐ
low|loʊ|ひくい
mow|moʊ|くさを かる
own|oʊn|じぶんのもの
snow|snoʊ|ゆき
'''

TOPICS = [
 ['s','a','t','p','i','n'], ['m','d','g','o','c','k'], ['e','u','b','h','f','l'],
 ['r','j','v','w','y','z'], ['x','qu','review','mix1','mix2','mix3'],
 ['sh','ch','th','thv','ng','ck'], ['st','sp','bl','pl','nd','nt'],
 ['a_e','i_e','o_e','u_e','mix4','mix5'], ['ai','ay','ee','ea','oa','ow'],
 ['mix6','mix7','mix8','mix9','mix10','mix11'],
]
ISLANDS = [
 ('はじまりの もり','はじめの おとを みつけよう','きつね',0xFF6A9565),
 ('まるたの かわ','おとを つないで ことばに','うさぎ',0xFF53A69C),
 ('はなさく おか','まんなかの おとを きこう','ねこ',0xFFC49C57),
 ('かぜの そうげん','いろいろな こえに であおう','いぬ',0xFF8B9B62),
 ('ひかりの まち','もじと おとを たしかめよう','くま',0xFFC6886B),
 ('しずかな みずうみ','ふたつの もじで ひとつの おと','あひる',0xFF6C9DB3),
 ('つながる はし','おとを つづけて いってみよう','かえる',0xFF70A98C),
 ('まほうの やま','さいごの e の ひみつ','ふくろう',0xFF9B8FBB),
 ('にじの みなと','おなじ おと、ちがう もじ','ぺんぎん',0xFFD39D64),
 ('ぼうけんの しま','はじめての ことばを よもう','らいおん',0xFFCD977A),
]

def tokenize(word):
    tokens = []
    i = 0
    silent = len(word) >= 4 and word[-1] == 'e' and word[-3] in 'aiou'
    while i < len(word):
        if silent and i == len(word)-3:
            tokens.append(word[i]+'_e'); i += 1
        elif silent and i == len(word)-1:
            i += 1
        elif word[i:i+2] in ('sh','ch','th','ng','ck','qu','ai','ay','ee','ea','oa','ow'):
            pair = word[i:i+2]
            tokens.append('thv' if pair == 'th' and word in ('this','that','them','then','than') else pair)
            i += 2
        else:
            tokens.append(word[i]); i += 1
    return tokens

def build():
    sounds = [dict(id=k,label=label,ipa=ipa,hint=hint,example=example,
                   audio=f'assets/audio/sound_{k}.wav',espeak=voice)
              for k,label,ipa,hint,example,voice in SOUNDS]
    source = sounds[:]
    for n, key in enumerate(['review']+[f'mix{i}' for i in range(1,12)]):
        s = dict(source[n % len(source)])
        s['id'] = key
        sounds.append(s)
    words = []
    examples = {s['example'] for s in sounds}
    consonants = set('bcdfghjklmnpqrstvwxyz')
    for row in ROWS.strip().splitlines():
        text, ipa, meaning = row.split('|')
        skills = tokenize(text)
        # Adjacent single consonants are a cluster, not sh/ch/ng/ck digraphs.
        blend = any(a in consonants and b in consonants for a,b in zip(skills,skills[1:]))
        words.append(dict(text=text,ipa=ipa,meaning=meaning,skills=skills,
            heldOut=len(words)%5 == 4 and text not in examples,blend=blend))
    islands = []
    lookup = {s['id']:s for s in sounds}
    for (name, subtitle, animal, color), topics in zip(ISLANDS,TOPICS):
        lessons = [dict(skill=k, title=(f'{lookup[k]["label"]} の おと' if not k.startswith(('mix','review'))
                    else 'ことばの パズル')) for k in topics]
        lessons.append(dict(skill=topics[0],title='しまの たからさがし'))
        islands.append(dict(name=name,subtitle=subtitle,animal=animal,color=color,lessons=lessons))
    result = dict(schema=1,status='draft-unreviewed',sounds=sounds,words=words,islands=islands)
    target=ROOT/'assets/data/curriculum.json'
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(f'{len(words)} words / {sum(w["heldOut"] for w in words)} held out / 70 lessons')

if __name__ == '__main__':
    build()
