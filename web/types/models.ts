// Aliases for the OpenAPI schema types (generated into ~/types/api.d.ts).
import type { components } from '~/types/api'

type Schemas = components['schemas']

export type ApiUser = Schemas['User']
export type ApiNovel = Schemas['Novel']
export type ApiNovelInput = Schemas['NovelInput']
export type ApiCategory = Schemas['Category']
export type ApiCategoryInput = Schemas['CategoryInput']
export type ApiChapter = Schemas['Chapter']
export type ApiChapterInput = Schemas['ChapterInput']
export type ApiChapterRef = Schemas['ChapterRef']
export type ApiChapterDetail = Schemas['ChapterDetail']
export type ApiBookshelfEntry = Schemas['BookshelfEntry']
export type ApiReadingProgress = Schemas['ReadingProgress']
export type ApiReadingHistory = Schemas['ReadingHistory']
export type ApiBookmark = Schemas['Bookmark']
export type ApiBookmarkInput = Schemas['BookmarkInput']
export type ApiReadingSettings = Schemas['ReadingSettings']
export type ApiReadingStats = Schemas['ReadingStats']
export type ApiReview = Schemas['Review']
export type ApiReviewInput = Schemas['ReviewInput']
export type ApiComment = Schemas['Comment']
export type ApiReportInput = Schemas['ReportInput']
export type ApiReport = Schemas['Report']
export type ApiReportView = Schemas['ReportView']
export type ApiBanner = Schemas['Banner']
export type ApiBannerInput = Schemas['BannerInput']
export type ApiHomePage = Schemas['HomePage']
export type ApiAdminStats = Schemas['AdminStats']
export type ApiLikeResult = Schemas['LikeResult']
export type ModerationStatus = Schemas['ModerationStatus']
export type ReportReason = ApiReportInput['reason']
export type ReportTargetType = ApiReportInput['target_type']
export type ApiParagraphCount = Schemas['ParagraphCount']
export type ApiNotification = Schemas['Notification']
export type NotificationType = Schemas['NotificationType']
export type ApiDevice = Schemas['Device']
export type ApiDeviceInput = Schemas['DeviceInput']
export type ApiBookshelfItemUpdate = Schemas['BookshelfItemUpdate']

export const REPORT_REASONS: { label: string, value: ReportReason }[] = [
  { label: '垃圾訊息', value: 'spam' },
  { label: '辱罵攻擊', value: 'abuse' },
  { label: '劇透', value: 'spoiler' },
  { label: '侵權', value: 'copyright' },
  { label: '不當內容', value: 'inappropriate' },
  { label: '其他', value: 'other' },
]
