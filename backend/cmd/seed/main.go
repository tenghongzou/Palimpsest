// Command seed fills a development database with categories, an admin
// account and a few sample novels. It is idempotent: existing rows are kept.
//
//	SEED_ADMIN_PASSWORD=... go run ./cmd/seed
//
// The admin account is only created when SEED_ADMIN_PASSWORD is set.
package main

import (
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/tenghongzou/palimpsest/backend/internal/config"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/repository"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"gorm.io/gorm/logger"
)

type category struct {
	name, slug string
	children   []category
}

var categories = []category{
	{"玄幻", "xuanhuan", []category{{"東方玄幻", "oriental-fantasy", nil}, {"異世大陸", "other-world", nil}}},
	{"奇幻", "fantasy", nil},
	{"武俠", "wuxia", nil},
	{"仙俠", "xianxia", []category{{"修真文明", "cultivation", nil}}},
	{"都市", "urban", nil},
	{"歷史", "history", nil},
	{"科幻", "scifi", nil},
	{"懸疑", "mystery", nil},
	{"言情", "romance", nil},
	{"輕小說", "light-novel", nil},
}

type sampleNovel struct {
	title, author, description, status, language, category string
	tags                                                   []string
	chapters                                               []sampleChapter
}

type sampleChapter struct{ title, content string }

// The sample texts are original placeholder stories written for this project.
var novels = []sampleNovel{
	{
		title: "霧港燈塔", author: "林硯", status: "ongoing", language: "zh-TW", category: "mystery",
		description: "海霧終年不散的港口，燈塔看守人每晚都會收到一封沒有寄件人的信。",
		tags:        []string{"懸疑", "海港", "書信"},
		chapters: []sampleChapter{
			{"第一章 無名的信", "霧從海面爬上來的時候，港口的燈一盞接一盞亮起。\n\n沈遙把最後一桶燈油提上塔頂，轉身時看見窗台上壓著一封信。信封很乾，像是剛剛才被放下，可是這座塔只有一道樓梯，而他整個下午都在樓梯口修補漁網。\n\n信上只有一行字：「今晚十點，別讓燈熄。」"},
			{"第二章 十點鐘", "九點五十分，風突然停了。\n\n沈遙守在燈旁，聽見塔下傳來敲門聲，三短一長，正是父親生前與他約定的暗號。可是父親已經在三年前的那場風暴裡失蹤了。\n\n他沒有下樓。十點整，燈芯劇烈地跳了一下，海面上浮現出一艘沒有掛旗的船。"},
			{"第三章 沒有旗的船", "天亮以後，港務所的人說昨晚沒有任何船隻進港。\n\n沈遙回到塔頂，在窗台上找到第二封信。這一次，信封上寫著他的名字，筆跡和父親的一模一樣。"},
		},
	},
	{
		title: "星砂旅人", author: "白芷", status: "completed", language: "zh-TW", category: "scifi",
		description: "在每一粒沙都記錄著一段記憶的星球上，一名少女踏上尋找失落城市的旅程。",
		tags:        []string{"科幻", "冒險", "成長"},
		chapters: []sampleChapter{
			{"第一章 會說話的沙", "阿禾第一次聽見沙子說話，是在她十二歲生日那天。\n\n那是一粒藍色的星砂，躺在她的掌心，用祖母的聲音說：「往北走，去找會發光的城。」\n\n村裡的大人都說北方只有風暴，沒有城市。"},
			{"第二章 風暴邊緣", "第七天，阿禾抵達風暴的邊緣。\n\n沙牆高得看不見頂，裡面閃爍著無數細小的光。她握緊那粒藍色星砂，聽見成千上萬的聲音同時響起，像是一座城市在呼吸。"},
			{"第三章 發光的城", "風暴的中心安靜得出奇。\n\n倒塌的高塔之間，每一粒沙都在發光。阿禾終於明白，這座城從來沒有消失，它只是變成了沙，等著有人把記憶帶回家。\n\n（全書完）"},
		},
	},
	{
		title: "青石劍譜", author: "顧行舟", status: "ongoing", language: "zh-CN", category: "wuxia",
		description: "一本被当作垫桌脚的旧剑谱，让小镇铁匠的学徒卷入了江湖纷争。",
		tags:        []string{"武侠", "江湖", "少年"},
		chapters: []sampleChapter{
			{"第一章 垫桌脚的书", "铁匠铺的桌子少了一截腿，师父随手拿了本旧书垫上，一垫就是十年。\n\n直到那天，一个戴斗笠的客人进门，盯着桌脚看了很久，然后放下一锭银子：「这本书，我买了。」"},
			{"第二章 夜半来客", "师父没有卖。当天夜里，铺子的门被人踢开了。\n\n陆小川躲在风箱后面，看见三个黑衣人翻遍了整间屋子。那本剑谱，此刻正贴身藏在他的怀里。"},
		},
	},
	{
		title: "潮聲密室", author: "林硯", status: "completed", language: "zh-TW", category: "mystery",
		description: "退潮後才會露出的石屋裡，躺著一位三天前就該離港的船長。",
		tags:        []string{"懸疑", "推理", "海港"},
		chapters: []sampleChapter{
			{"第一章 退潮", "每個月只有大潮那天，石屋的門才會露出水面。\n\n巡港員敲了三下門，沒有人應。門從裡面閂上了，而屋裡唯一的窗，正對著還在退去的海。"},
			{"第二章 濕透的鑰匙", "鑰匙在船長的口袋裡，濕得滴水。\n\n可是石屋的地板是乾的。有人在漲潮之前進來，又在門被海水封住之後離開——除非，他從來沒有離開。"},
		},
	},
	{
		title: "夜車上的證人", author: "許青", status: "ongoing", language: "zh-TW", category: "mystery",
		description: "末班夜車上只有七名乘客，到站時卻多了一張無人認領的車票。",
		tags:        []string{"懸疑", "推理"},
		chapters: []sampleChapter{
			{"第一章 第八張票", "車掌第三次清點車票，仍然是八張。\n\n車廂裡只有七個人，每個人都說自己上車時，對面的位子是空的。"},
			{"第二章 窗上的字", "列車駛進隧道，玻璃上浮出一行被呵氣寫下的字：「我一直坐在這裡。」"},
		},
	},
	{
		title: "沙海信標", author: "白芷", status: "ongoing", language: "zh-TW", category: "scifi",
		description: "在沙海中漂流的信標每晚發出求救訊號，訊號裡的聲音屬於一百年前的探險隊。",
		tags:        []string{"科幻", "冒險"},
		chapters: []sampleChapter{
			{"第一章 第一百年的訊號", "通訊塔收到訊號的那一刻，所有螢幕同時亮起同一個座標。\n\n那是一百年前探險隊失聯的位置，而訊號裡的人說：「我們還在等。」"},
			{"第二章 沙下的船", "沙丘移動了一整夜。天亮時，一艘半埋在沙裡的船露出船首，船身上的編號和檔案裡的一模一樣。"},
		},
	},
}

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	db, err := gorm.Open(postgres.Open(cfg.DB.DSN()), &gorm.Config{Logger: logger.Default.LogMode(logger.Warn)})
	if err != nil {
		log.Fatalf("connect database: %v", err)
	}
	if err := db.AutoMigrate(model.All()...); err != nil {
		log.Fatalf("migrate: %v", err)
	}

	slugs, err := seedCategories(db)
	if err != nil {
		log.Fatalf("categories: %v", err)
	}
	if err := seedAdmin(db); err != nil {
		log.Fatalf("admin: %v", err)
	}
	if err := seedNovels(db, slugs); err != nil {
		log.Fatalf("novels: %v", err)
	}
	log.Println("seed complete; restart the API server to index the sample novels for search")
}

func seedCategories(db *gorm.DB) (map[string]int, error) {
	ids := map[string]int{}
	var save func(cs []category, parent *int) error
	save = func(cs []category, parent *int) error {
		for i, c := range cs {
			row := model.Category{Name: c.name, Slug: c.slug, ParentID: parent, SortOrder: i, IsActive: true}
			if err := db.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "slug"}}, DoNothing: true}).Create(&row).Error; err != nil {
				return err
			}
			if err := db.Where("slug = ?", c.slug).First(&row).Error; err != nil {
				return err
			}
			ids[c.slug] = row.ID
			if err := save(c.children, &row.ID); err != nil {
				return err
			}
		}
		return nil
	}
	if err := save(categories, nil); err != nil {
		return nil, err
	}
	log.Printf("categories: %d", len(ids))
	return ids, nil
}

func seedAdmin(db *gorm.DB) error {
	password := os.Getenv("SEED_ADMIN_PASSWORD")
	if password == "" {
		log.Println("admin: SEED_ADMIN_PASSWORD not set, skipping")
		return nil
	}
	if len(password) < 8 {
		return errors.New("SEED_ADMIN_PASSWORD must be at least 8 characters")
	}
	username := envOr("SEED_ADMIN_USERNAME", "admin")
	email := envOr("SEED_ADMIN_EMAIL", "admin@palimpsest.local")

	var count int64
	if err := db.Model(&model.User{}).Where("username = ?", username).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		log.Printf("admin: %s already exists", username)
		return nil
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	admin := model.User{Username: username, Email: &email, PasswordHash: string(hash), Nickname: "管理員", Role: "admin", Status: "active", LanguagePref: "zh-TW"}
	if err := db.Create(&admin).Error; err != nil {
		return err
	}
	log.Printf("admin: created %s <%s>", username, email)
	return nil
}

func seedNovels(db *gorm.DB, categoryIDs map[string]int) error {
	repo := repository.NewNovelRepository(db)
	for _, n := range novels {
		var count int64
		if err := db.Model(&model.Novel{}).Where("title = ? AND author_name = ?", n.title, n.author).Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			log.Printf("novel: %s already exists", n.title)
			continue
		}
		now := time.Now()
		novel := model.Novel{
			Title: n.title, AuthorName: n.author, Description: n.description, Status: n.status,
			Language: n.language, IsPublished: true, IsFeatured: true, PublishedAt: &now,
		}
		err := db.Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&novel).Error; err != nil {
				return err
			}
			if id, ok := categoryIDs[n.category]; ok {
				if err := tx.Model(&novel).Association("Categories").Append(&model.Category{ID: id}); err != nil {
					return err
				}
			}
			for _, name := range n.tags {
				tag := model.Tag{Name: name}
				if err := tx.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "name"}}, DoNothing: true}).Create(&tag).Error; err != nil {
					return err
				}
				if err := tx.Where("name = ?", name).First(&tag).Error; err != nil {
					return err
				}
				if err := tx.Model(&novel).Association("Tags").Append(&tag); err != nil {
					return err
				}
			}
			for i, c := range n.chapters {
				ch := model.Chapter{NovelID: novel.ID, Title: c.title, Content: strings.TrimSpace(c.content), ChapterNumber: i + 1, IsPublished: true, IsFree: true}
				if err := tx.Create(&ch).Error; err != nil {
					return fmt.Errorf("chapter %d: %w", i+1, err)
				}
			}
			return nil
		})
		if err != nil {
			return fmt.Errorf("%s: %w", n.title, err)
		}
		if err := repo.RefreshStats(novel.ID); err != nil {
			return err
		}
		log.Printf("novel: created %s (%d chapters)", n.title, len(n.chapters))
	}
	return nil
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
