const BASE_URL = 'http://localhost:8080'; 

class ApiService {
  constructor() {
    this.baseURL = BASE_URL;
    this.token = localStorage.getItem('access_token');
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    
    const config = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    };

    if (this.token) {
      config.headers.Authorization = `Bearer ${this.token}`;
    }

    try {
      const response = await fetch(url, config);
      
      if (response.status === 204) {
        return {}; 
      }
      
      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || `HTTP error! status: ${response.status}`);
      }

      return data;
    } catch (error) {
      console.error('API request failed:', error);
      throw error;
    }
  }

  async signup(userData) {
    const response = await this.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({
        first_name: userData.firstName,
        last_name: userData.lastName,
        email: userData.email,
        password1: userData.password,
        password2: userData.confirmPassword,
        city: userData.city,
        country: userData.country || 'Colombia',
      }),
    });
    return response;
  }

  async login(email, password) {
    const response = await this.request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        email,
        password,
      }),
    });
    
    if (response.access_token) {
      this.token = response.access_token;
      localStorage.setItem('access_token', response.access_token);
    }
    
    return response;
  }

  // Note: added route to Go backend
  // authGroup.GET("/profile", middleware.AuthMiddleware(cfg), authHandler.GetProfile)
  async getProfile() {
    return await this.request('/api/auth/profile');
  }

  // Video methods
  async uploadVideo(title, file) {
    const formData = new FormData();
    formData.append('title', title);
    formData.append('video_file', file);

    const response = await fetch(`${this.baseURL}/api/videos/upload`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.token}`,
      },
      body: formData, // Don't set Content-Type for FormData
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Upload failed');
    }

    return await response.json();
  }

  async getMyVideos() {
    return await this.request('/api/videos');
  }

  async getVideoDetail(videoId) {
    return await this.request(`/api/videos/${videoId}`);
  }

  async deleteVideo(videoId) {
    return await this.request(`/api/videos/${videoId}`, {
      method: 'DELETE',
    });
  }

  async getPublicVideos() {
    return await this.request('/api/public/videos');
  }

  async voteVideo(videoId) {
    return await this.request(`/api/public/videos/${videoId}/vote`, {
      method: 'POST',
    });
  }

  async getRankings(page = 1, limit = 50, city = '') {
    const params = new URLSearchParams();
    if (page) params.append('page', page);
    if (limit) params.append('limit', limit);
    if (city && city !== 'todas') params.append('city', city);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return await this.request(`/api/public/rankings${query}`);
  }

  logout() {
    this.token = null;
    localStorage.removeItem('access_token');
  }

  isAuthenticated() {
    return !!this.token;
  }

  setToken(token) {
    this.token = token;
    localStorage.setItem('access_token', token);
  }
}

export default new ApiService();