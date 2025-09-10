# ANB Rising Stars Showcase - Frontend

Frontend web application for the ANB Rising Stars basketball talent showcase competition.

## Features

### Authentication
- User registration and login
- JWT-based authentication
- Profile management

### Video Management
- Video upload with drag & drop support
- Real-time processing status tracking
- My Videos dashboard

### Public Voting System
- Browse public videos
- Vote for favorite players
- Real-time vote counting

### Rankings & Leaderboard
- City-based rankings
- National leaderboard
- Real-time statistics

### Responsive Design
- Mobile-first approach
- Modern UI with Tailwind CSS
- Smooth animations and transitions

## Tech Stack

- **Framework**: React 19
- **Styling**: Tailwind CSS
- **Icons**: Lucide React
- **Build Tool**: Vite
- **State Management**: React Hooks
- **API Communication**: Fetch API

## Installation

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Start development server**
   ```bash
   npm run dev
   ```

3. **Build for production**
   ```bash
   npm run build
   ```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VITE_API_URL` | Backend API URL | `http://localhost:8080` |
| `VITE_APP_NAME` | Application name | `ANB Rising Stars Showcase` |
| `VITE_ENVIRONMENT` | Environment | `development` |

## Available Scripts

- `npm run dev` - Start development server (port 5173)
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

## Pages & Features

### Landing Page
- Hero section with call-to-action
- Feature showcase
- Statistics overview

### Authentication
- Login/Register forms with validation
- Error handling

### Dashboard
- User statistics and progress tracking
- Recent videos overview

### Video Upload
- Drag & drop file upload
- Progress tracking and processing status

### Videos Gallery
- Grid layout with filtering
- Public voting functionality

### Rankings
- City-based filtering and leaderboard
- Real-time statistics

### Profile
- User information and video history

## API Integration

The frontend integrates with the Go backend API with these endpoints:

- **POST /api/auth/signup** - User registration
- **POST /api/auth/login** - User login
- **GET /api/auth/profile** - Get user profile
- **POST /api/videos/upload** - Upload video
- **GET /api/videos** - Get user videos
- **GET /api/videos/{id}** - Get video details
- **DELETE /api/videos/{id}** - Delete video
- **GET /api/public/videos** - Get public videos
- **POST /api/public/videos/{id}/vote** - Vote for video
- **GET /api/public/rankings** - Get rankings

## Running the Application

1. **Start the backend** (port 8080)
2. **Start the frontend**:
   ```bash
   cd front
   npm install
   npm run dev
   ```
3. **Access the app**: http://localhost:3000

