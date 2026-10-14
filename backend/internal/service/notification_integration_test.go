package service

import (
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/testutil"
)

func TestReplyNotificationsAndParagraphCounts(t *testing.T) {
	db := testutil.DB(t)
	notes := NewNotificationService(db)
	svc := NewCommunityService(db, nil).WithNotifications(notes)
	alice := testutil.User(t, db, "")
	bob := testutil.User(t, db, "")
	novel, chapters := testutil.Novel(t, db, 1)
	ch := chapters[0].ID

	p2, p5 := 2, 5
	thread, err := svc.CreateComment(alice.ID, ch, CommentInput{Content: "好段落", ParagraphIndex: &p2})
	if err != nil {
		t.Fatalf("CreateComment: %v", err)
	}
	if _, err := svc.CreateComment(bob.ID, ch, CommentInput{Content: "同感", ParagraphIndex: &p2}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.CreateComment(bob.ID, ch, CommentInput{Content: "伏筆", ParagraphIndex: &p5}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.CreateComment(bob.ID, ch, CommentInput{Content: "整章留言"}); err != nil {
		t.Fatal(err)
	}
	// Replies notify the author and do not count toward paragraphs.
	reply, err := svc.CreateComment(bob.ID, ch, CommentInput{Content: "我也這麼覺得", ParentID: &thread.ID, ParagraphIndex: &p5})
	if err != nil {
		t.Fatal(err)
	}
	if reply.ParagraphIndex != nil {
		t.Errorf("reply paragraph_index = %v, want nil", *reply.ParagraphIndex)
	}
	if _, err := svc.CreateComment(alice.ID, ch, CommentInput{Content: "謝謝", ParentID: &reply.ID}); err != nil {
		t.Fatal(err)
	}

	// Any comment of a thread leads to the whole thread.
	got, err := svc.GetThread(reply.ID, &alice.ID)
	if err != nil || got.ID != thread.ID || len(got.Replies) != 2 || *got.ParagraphIndex != p2 {
		t.Errorf("GetThread = %+v, %v", got, err)
	}
	if _, err := svc.GetThread(uuid.New(), nil); !errors.Is(err, ErrNotFound) {
		t.Errorf("GetThread unknown: err = %v", err)
	}

	counts, err := svc.ParagraphCounts(ch)
	if err != nil {
		t.Fatalf("ParagraphCounts: %v", err)
	}
	if len(counts) != 2 || counts[0] != (ParagraphCount{2, 2}) || counts[1] != (ParagraphCount{5, 1}) {
		t.Errorf("counts = %+v", counts)
	}

	// Alice's reply to Bob notifies Bob; her own thread reply notifies nobody else.
	items, total, err := notes.List(alice.ID, false, 1, 20)
	if err != nil || total != 1 {
		t.Fatalf("alice notifications: total=%d err=%v", total, err)
	}
	n := items[0]
	if n.Type != model.NotificationCommentReply || n.Actor == nil || n.Actor.ID != bob.ID ||
		*n.ChapterID != ch || *n.NovelID != novel.ID || *n.CommentID != thread.ID || n.ReadAt != nil {
		t.Errorf("alice notification = %+v", n)
	}
	if _, total, _ := notes.List(bob.ID, false, 1, 20); total != 1 {
		t.Errorf("bob notifications = %d, want 1", total)
	}

	// Read state.
	if c, _ := notes.UnreadCount(alice.ID); c != 1 {
		t.Errorf("unread = %d", c)
	}
	if err := notes.MarkRead(bob.ID, n.ID); !errors.Is(err, ErrNotFound) {
		t.Errorf("marking someone else's notification: err = %v", err)
	}
	if err := notes.MarkRead(alice.ID, n.ID); err != nil {
		t.Fatal(err)
	}
	if c, _ := notes.UnreadCount(alice.ID); c != 0 {
		t.Errorf("unread after read = %d", c)
	}
	if _, total, _ := notes.List(alice.ID, true, 1, 20); total != 0 {
		t.Errorf("unread list = %d", total)
	}
	if err := notes.Delete(alice.ID, n.ID); err != nil {
		t.Fatal(err)
	}
	if err := notes.Delete(alice.ID, n.ID); !errors.Is(err, ErrNotFound) {
		t.Errorf("second delete: err = %v", err)
	}
}

func TestChapterUpdateNotifications(t *testing.T) {
	db := testutil.DB(t)
	notes := NewNotificationService(db)
	shelf := NewBookshelfService(nil, db)
	reader := testutil.User(t, db, "")
	muted := testutil.User(t, db, "")
	stranger := testutil.User(t, db, "")
	novel, chapters := testutil.Novel(t, db, 4)
	for _, u := range []*model.User{reader, muted} {
		if err := db.Create(&model.BookshelfItem{UserID: u.ID, NovelID: novel.ID, IsNotified: true}).Error; err != nil {
			t.Fatal(err)
		}
	}
	off := false
	if err := shelf.UpdateItem(muted.ID, novel.ID, ItemUpdate{IsNotified: &off}); err != nil {
		t.Fatal(err)
	}

	if err := notes.NotifyChapters(novel.ID, chapters[2:3]); err != nil {
		t.Fatalf("NotifyChapters: %v", err)
	}
	// A second update before the first is read folds into it.
	if err := notes.NotifyChapters(novel.ID, chapters[3:4]); err != nil {
		t.Fatal(err)
	}
	items, total, _ := notes.List(reader.ID, false, 1, 20)
	if total != 1 {
		t.Fatalf("reader notifications = %d, want 1", total)
	}
	if n := items[0]; n.Type != model.NotificationChapterUpdate || *n.ChapterID != chapters[2].ID || n.Body != "更新至：第4章" {
		t.Errorf("notification = %+v", n)
	}
	for _, u := range []*model.User{muted, stranger} {
		if _, total, _ := notes.List(u.ID, false, 1, 20); total != 0 {
			t.Errorf("user %s got %d notifications", u.Username, total)
		}
	}

	// Once read, the next update is a new notification.
	if _, err := notes.MarkAllRead(reader.ID); err != nil {
		t.Fatal(err)
	}
	if err := notes.NotifyChapters(novel.ID, chapters[1:4]); err != nil {
		t.Fatal(err)
	}
	items, total, _ = notes.List(reader.ID, true, 1, 20)
	if total != 1 || *items[0].ChapterID != chapters[1].ID {
		t.Errorf("after read: total=%d items=%+v", total, items)
	}

	// Unpublished novels notify nobody.
	db.Model(novel).Update("is_published", false)
	notes.MarkAllRead(reader.ID)
	if err := notes.NotifyChapters(novel.ID, chapters[:1]); err != nil {
		t.Fatal(err)
	}
	if c, _ := notes.UnreadCount(reader.ID); c != 0 {
		t.Errorf("unpublished novel notified %d", c)
	}

	// Broadcasts reach every active user.
	n, err := notes.Broadcast("系統維護", "今晚 23:00")
	if err != nil || n != 3 {
		t.Errorf("Broadcast = %d, %v", n, err)
	}
}

func TestDevices(t *testing.T) {
	db := testutil.DB(t)
	notes := NewNotificationService(db)
	alice := testutil.User(t, db, "")
	bob := testutil.User(t, db, "")

	phone, err := notes.RegisterDevice(alice.ID, DeviceInput{DeviceID: "dev-1", DeviceType: "android", DeviceName: "Pixel", PushToken: "tok"})
	if err != nil {
		t.Fatalf("RegisterDevice: %v", err)
	}
	again, err := notes.RegisterDevice(alice.ID, DeviceInput{DeviceID: "dev-1", DeviceType: "android", DeviceName: "Pixel 9", PushToken: "tok"})
	if err != nil || again.ID != phone.ID || again.DeviceName != "Pixel 9" {
		t.Errorf("re-register = %+v, %v", again, err)
	}
	// The same installation signing in as Bob takes the push token with it.
	if _, err := notes.RegisterDevice(bob.ID, DeviceInput{DeviceID: "dev-1", DeviceType: "android", PushToken: "tok"}); err != nil {
		t.Fatal(err)
	}
	if d := reload[model.UserDevice](t, db, phone.ID); d.PushToken != "" {
		t.Errorf("alice kept push token %q", d.PushToken)
	}

	for i := 0; i < maxDevicesPerUser+3; i++ {
		if _, err := notes.RegisterDevice(alice.ID, DeviceInput{DeviceID: uuid.NewString(), DeviceType: "web"}); err != nil {
			t.Fatal(err)
		}
	}
	devices, _ := notes.ListDevices(alice.ID)
	if len(devices) != maxDevicesPerUser {
		t.Errorf("devices = %d, want %d", len(devices), maxDevicesPerUser)
	}
	if err := notes.RemoveDevice(bob.ID, devices[0].ID); !errors.Is(err, ErrNotFound) {
		t.Errorf("removing another user's device: err = %v", err)
	}
	if err := notes.RemoveDevice(alice.ID, devices[0].ID); err != nil {
		t.Fatal(err)
	}
}
