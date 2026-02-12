export interface User {
  id: string
  username: string
  email: string
  nickname: string
  avatar_url: string
  bio: string
  role: 'reader' | 'author' | 'admin' | 'super_admin'
  language_pref: 'zh-TW' | 'zh-CN' | 'en'
  total_read_words: number
  total_read_seconds: number
  created_at: string
}

export interface LoginRequest {
  login: string
  password: string
}

export interface RegisterRequest {
  username: string
  email: string
  password: string
  nickname: string
}

export interface AuthResponse {
  user: User
  access_token: string
  refresh_token: string
  expires_in: number
}
