import React, { useState, useEffect } from 'react';
import { Upload, Play, Trophy, User, Home, LogOut, ThumbsUp, Video, Star, TrendingUp, CheckCircle, Clock, XCircle, Loader2, ChevronRight, Award, Users, MapPin, Calendar, Eye, Filter, BarChart3, Shield } from 'lucide-react';

// Componente UploadVideo separado para evitar re-renders
const UploadVideo = ({
  selectedFile,
  setSelectedFile,
  videoTitle,
  setVideoTitle,
  uploading,
  setUploading,
  dragActive,
  setDragActive,
  uploadError,
  setUploadError,
  videoIsPublic,
  setVideoIsPublic,
  processingStatus,
  setProcessingStatus,
  uploadProgress,
  setUploadProgress,
  resetUploadForm,
  apiService
}) => {
  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  };

  const handleFileSelect = (file) => {
    const validation = validateVideoFile(file);

    if (validation.isValid) {
      setSelectedFile(file);
      setUploadError('');
      setProcessingStatus(null);
      setUploadProgress(0);
      setUploading(false);
    } else {
      setUploadError(validation.errors.join('. '));
      setSelectedFile(null);
    }
  };

  const handleUpload = async () => {
    if (!selectedFile || !videoTitle.trim()) {
      setUploadError('Por favor proporciona un título y selecciona un archivo de video');
      return;
    }

    // Validate file again before upload
    const validation = validateVideoFile(selectedFile);
    if (!validation.isValid) {
      setUploadError(validation.errors.join('. '));
      return;
    }

    setUploading(true);
    setProcessingStatus('uploading');
    setUploadProgress(0);
    setUploadError('');

    // Simulate upload progress
    let progress = 0;
    const interval = setInterval(() => {
      progress += Math.random() * 15;
      if (progress > 90) progress = 90;
      setUploadProgress(progress);
    }, 500);

    try {
      await apiService.uploadVideo(videoTitle.trim(), selectedFile, videoIsPublic);
      clearInterval(interval);
      setUploadProgress(100);
      setProcessingStatus('processing');
      setTimeout(() => {
        resetUploadForm();
        setProcessingStatus('completed');
      }, 2000);
    } catch (err) {
      clearInterval(interval);
      setUploadError(`Error al subir el video: ${err.message || 'Error desconocido'}`);
      setUploading(false);
      setProcessingStatus(null);
      setUploadProgress(0);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 p-6">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-gray-800 mb-2">Sube tu Video</h1>
          <p className="text-gray-600">Comparte tu mejor jugada en el torneo</p>
        </div>

        <div className="bg-white rounded-2xl shadow-xl overflow-hidden">
          <div className="bg-gradient-to-r from-orange-500 to-red-500 p-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-2xl font-bold text-white mb-1">Nueva Subida</h2>
                <p className="text-orange-100">Formatos soportados: MP4, AVI, MOV (máx. 100MB)</p>
              </div>
              <Video className="w-16 h-16 text-white opacity-80" />
            </div>
          </div>

          <div className="p-8">
            {uploadError && (
              <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl mb-6">
                {uploadError}
              </div>
            )}

            {!processingStatus && (
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Título del video *
                </label>
                <input
                  type="text"
                  placeholder="Ej: Mejores jugadas - Juan Pérez"
                  value={videoTitle}
                  onChange={(e) => setVideoTitle(e.target.value)}
                  className="w-full p-3 border-2 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                  maxLength={100}
                />
                <p className="text-sm text-gray-500 mt-1">{videoTitle.length}/100 caracteres</p>
              </div>
            )}

            {!processingStatus && (
              <div className="mb-6">
                <label className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    checked={videoIsPublic}
                    onChange={(e) => setVideoIsPublic(e.target.checked)}
                    className="w-4 h-4 text-orange-500 border-2 border-gray-300 rounded focus:ring-orange-500"
                  />
                  <span className="text-sm font-medium text-gray-700">
                    Mantener este video público (visible para votación pública)
                  </span>
                </label>
                <p className="text-xs text-gray-500 mt-1">
                  {videoIsPublic
                    ? 'Tu video será visible en la votación pública y en tu perfil'
                    : 'Los videos privados solo serán visibles en tu perfil personal'
                  }
                </p>
              </div>
            )}

            {!processingStatus && (
              <div
                className={`border-2 border-dashed rounded-xl p-8 text-center transition-all ${dragActive
                    ? 'border-orange-500 bg-orange-50'
                    : selectedFile
                      ? 'border-green-500 bg-green-50'
                      : 'border-gray-300 hover:border-orange-400 hover:bg-orange-50'
                  }`}
                onDragEnter={handleDrag}
                onDragLeave={handleDrag}
                onDragOver={handleDrag}
                onDrop={handleDrop}
              >
                {selectedFile ? (
                  <div className="space-y-4">
                    <CheckCircle className="w-16 h-16 mx-auto text-green-500" />
                    <div>
                      <p className="text-green-700 font-semibold text-lg">Archivo seleccionado</p>
                      <p className="text-gray-600">{selectedFile.name}</p>
                      <div className="text-sm space-y-1">
                        <p className={`${selectedFile.size > VIDEO_VALIDATIONS.MAX_SIZE ? 'text-red-500 font-semibold' : 'text-gray-500'}`}>
                          Tamaño: {(selectedFile.size / (1024 * 1024)).toFixed(2)} MB
                          {selectedFile.size > VIDEO_VALIDATIONS.MAX_SIZE && ' (¡Demasiado grande!)'}
                        </p>
                        <p className="text-gray-500">
                          Tipo: {selectedFile.type || 'Desconocido'}
                        </p>
                      </div>
                    </div>
                    <button
                      onClick={() => setSelectedFile(null)}
                      className="text-red-500 hover:text-red-700 transition-colors"
                    >
                      Cambiar archivo
                    </button>
                  </div>
                ) : (
                  <div className="space-y-4">
                    <Upload className="w-16 h-16 mx-auto text-gray-400" />
                    <div>
                      <p className="text-lg font-semibold text-gray-700 mb-2">
                        Arrastra tu video aquí o haz clic para seleccionar
                      </p>
                      <p className="text-gray-500">Formatos soportados: MP4, AVI, MOV</p>
                    </div>
                    <input
                      type="file"
                      accept=".mp4,.avi,.mov,video/mp4,video/avi,video/mov,video/quicktime"
                      onChange={(e) => e.target.files[0] && handleFileSelect(e.target.files[0])}
                      className="hidden"
                      id="file-upload"
                    />
                    <label
                      htmlFor="file-upload"
                      className="inline-block bg-gradient-to-r from-orange-500 to-red-500 text-white px-6 py-3 rounded-lg font-semibold cursor-pointer hover:shadow-lg transform hover:scale-105 transition-all"
                    >
                      Seleccionar archivo
                    </label>
                  </div>
                )}
              </div>
            )}

            {processingStatus && (
              <div className="text-center py-8">
                {processingStatus === 'uploading' && (
                  <div className="space-y-4">
                    <Loader2 className="w-16 h-16 mx-auto text-orange-500 animate-spin" />
                    <div>
                      <p className="text-lg font-semibold text-gray-700">Subiendo video...</p>
                      <div className="w-full bg-gray-200 rounded-full h-3 mt-3">
                        <div
                          className="bg-gradient-to-r from-orange-500 to-red-500 h-3 rounded-full transition-all duration-300"
                          style={{ width: `${uploadProgress}%` }}
                        ></div>
                      </div>
                      <p className="text-sm text-gray-500 mt-2">{Math.round(uploadProgress)}% completado</p>
                    </div>
                  </div>
                )}

                {processingStatus === 'processing' && (
                  <div className="space-y-4">
                    <Clock className="w-16 h-16 mx-auto text-blue-500" />
                    <div>
                      <p className="text-lg font-semibold text-gray-700">Procesando video...</p>
                      <p className="text-gray-500">Esto puede tomar unos minutos</p>
                    </div>
                  </div>
                )}

                {processingStatus === 'completed' && (
                  <div className="space-y-4">
                    <CheckCircle className="w-16 h-16 mx-auto text-green-500" />
                    <div>
                      <p className="text-lg font-semibold text-green-700">
                        {videoIsPublic ? '¡Video procesado con éxito!' : '¡Video procesado con éxito!'}
                      </p>
                      <p className="text-gray-600">
                        {videoIsPublic
                          ? 'Video Público: Tu video está disponible en la votación pública'
                          : 'Video Privado: Tu video solo será visible en tu perfil personal'
                        }
                      </p>
                    </div>
                  </div>
                )}
              </div>
            )}

            {!processingStatus && selectedFile && videoTitle.trim() && (
              <div className="mt-8 text-center">
                <button
                  onClick={handleUpload}
                  disabled={uploading}
                  className="bg-gradient-to-r from-orange-500 to-red-500 text-white px-8 py-4 rounded-xl font-semibold text-lg hover:shadow-lg transform hover:scale-105 transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
                >
                  {uploading ? 'Subiendo...' : 'Subir Video'}
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

// Sistema de carga de videos (componente optimizado para evitar pérdida de focus)
const UploadVideoView = ({
  selectedFile,
  setSelectedFile,
  videoTitle,
  setVideoTitle,
  uploading,
  setUploading,
  dragActive,
  setDragActive,
  uploadError,
  setUploadError,
  videoIsPublic,
  setVideoIsPublic,
  processingStatus,
  setProcessingStatus,
  uploadProgress,
  setUploadProgress,
  resetUploadForm,
  apiService,
  setCurrentView
}) => {
  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  };

  const handleFileSelect = (file) => {
    const validation = validateVideoFile(file);

    if (validation.isValid) {
      setSelectedFile(file);
      setUploadError('');
      setProcessingStatus(null);
      setUploadProgress(0);
      setUploading(false);
    } else {
      setUploadError(validation.errors.join('. '));
      setSelectedFile(null);
    }
  };

  const handleUpload = async () => {
    if (!selectedFile || !videoTitle.trim()) {
      setUploadError('Por favor proporciona un título y selecciona un archivo de video');
      return;
    }

    // Validate file again before upload
    const validation = validateVideoFile(selectedFile);
    if (!validation.isValid) {
      setUploadError(validation.errors.join('. '));
      return;
    }

    setUploading(true);
    setProcessingStatus('uploading');
    setUploadProgress(0);
    setUploadError('');

    // Simulate upload progress
    let progress = 0;
    const interval = setInterval(() => {
      progress += Math.random() * 15;
      if (progress > 90) progress = 90;
      setUploadProgress(Math.round(progress));
    }, 500);

    try {
      await apiService.uploadVideo(videoTitle.trim(), selectedFile, videoIsPublic);
      clearInterval(interval);
      setUploadProgress(100);
      setProcessingStatus('processing');

      setTimeout(() => {
        setProcessingStatus('completed');
        setUploading(false);
      }, 3000);
    } catch (err) {
      clearInterval(interval);
      console.error('Upload error details:', err);
      setUploadError(`Error al subir el video: ${err.message || 'Error desconocido'}`);
      setUploading(false);
      setProcessingStatus(null);
      setUploadProgress(0);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 p-4">
      <div className="max-w-4xl mx-auto">
        <h2 className="text-4xl font-bold mb-8 text-gray-800">Sube tu Video de Prueba</h2>

        <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
          <div className="bg-gradient-to-r from-orange-500 to-red-500 p-6 text-white">
            <h3 className="text-2xl font-bold mb-2">Requisitos del Video</h3>
            <div className="grid md:grid-cols-2 gap-4 text-sm">
              <div className="flex items-start space-x-2">
                <CheckCircle size={16} className="mt-0.5 flex-shrink-0" />
                <span>Duración máxima: 30 segundos</span>
              </div>
              <div className="flex items-start space-x-2">
                <CheckCircle size={16} className="mt-0.5 flex-shrink-0" />
                <span>Formato: MP4, MOV, AVI</span>
              </div>
              <div className="flex items-start space-x-2">
                <CheckCircle size={16} className="mt-0.5 flex-shrink-0" />
                <span>Resolución mínima: 720p</span>
              </div>
              <div className="flex items-start space-x-2">
                <CheckCircle size={16} className="mt-0.5 flex-shrink-0" />
                <span>Tamaño máximo: 100MB</span>
              </div>
            </div>
          </div>

          <div className="p-8">
            {uploadError && (
              <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl mb-6">
                {uploadError}
              </div>
            )}

            {!processingStatus && (
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Título del video *
                </label>
                <input
                  type="text"
                  placeholder="Ej: Mejores jugadas - Juan Pérez"
                  value={videoTitle}
                  onChange={(e) => setVideoTitle(e.target.value)}
                  className="w-full p-3 border-2 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                  maxLength={100}
                />
                <p className="text-sm text-gray-500 mt-1">{videoTitle.length}/100 caracteres</p>
              </div>
            )}

            {!processingStatus && (
              <div className="mb-6">
                <label className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    checked={videoIsPublic}
                    onChange={(e) => setVideoIsPublic(e.target.checked)}
                    className="w-4 h-4 text-orange-500 border-2 border-gray-300 rounded focus:ring-orange-500"
                  />
                  <span className="text-sm font-medium text-gray-700">
                    Mantener este video público (visible para votación pública)
                  </span>
                </label>
                <p className="text-xs text-gray-500 mt-1">
                  {videoIsPublic
                    ? 'Tu video será visible en la votación pública y en tu perfil'
                    : 'Los videos privados solo serán visibles en tu perfil personal'
                  }
                </p>
              </div>
            )}

            {!selectedFile && !processingStatus && (
              <div
                className={`border-3 border-dashed rounded-2xl p-12 text-center transition-all ${dragActive ? 'border-orange-500 bg-orange-50' : 'border-gray-300 hover:border-orange-400'
                  }`}
                onDragEnter={handleDrag}
                onDragLeave={handleDrag}
                onDragOver={handleDrag}
                onDrop={handleDrop}
              >
                <Upload className="w-20 h-20 mx-auto mb-4 text-gray-400" />
                <p className="text-2xl mb-2 text-gray-700">Arrastra tu video aquí</p>
                <p className="text-gray-500 mb-4">o</p>
                <label className="cursor-pointer">
                  <input
                    type="file"
                    accept=".mp4,.avi,.mov,video/mp4,video/avi,video/mov,video/quicktime"
                    onChange={(e) => handleFileSelect(e.target.files[0])}
                    className="hidden"
                  />
                  <span className="bg-gradient-to-r from-orange-500 to-red-500 text-white px-8 py-3 rounded-full font-bold hover:shadow-lg transition-all inline-block">
                    Seleccionar archivo
                  </span>
                </label>
              </div>
            )}

            {selectedFile && !uploading && !processingStatus && (
              <div className="text-center">
                <Video className="w-20 h-20 mx-auto mb-4 text-orange-500" />
                <p className="text-xl mb-2 text-gray-700 font-semibold">{selectedFile.name}</p>
                <div className="text-gray-500 mb-6 space-y-1">
                  <p className={`${selectedFile.size > VIDEO_VALIDATIONS.MAX_SIZE ? 'text-red-500 font-semibold' : ''}`}>
                    Tamaño: {(selectedFile.size / (1024 * 1024)).toFixed(2)} MB
                    {selectedFile.size > VIDEO_VALIDATIONS.MAX_SIZE && ' (¡Supera el límite de 100MB!)'}
                  </p>
                  <p>Tipo: {selectedFile.type || 'Desconocido'}</p>
                  <div className="flex items-center mt-2">
                    <CheckCircle className="w-4 h-4 text-green-500 mr-1" />
                    <span className="text-sm text-green-600">Formato válido</span>
                  </div>
                </div>
                <div className="flex gap-4 justify-center">
                  <button
                    onClick={() => setSelectedFile(null)}
                    className="bg-gray-200 text-gray-700 px-6 py-3 rounded-full font-semibold hover:bg-gray-300 transition-colors"
                  >
                    Cambiar archivo
                  </button>
                  <button
                    onClick={handleUpload}
                    className="bg-gradient-to-r from-orange-500 to-red-500 text-white px-8 py-3 rounded-full font-bold hover:shadow-lg transform hover:scale-105 transition-all"
                  >
                    Subir Video
                  </button>
                </div>
              </div>
            )}

            {processingStatus && (
              <div className="space-y-6">
                {processingStatus === 'uploading' && (
                  <div>
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-lg font-semibold text-gray-700">Subiendo video...</span>
                      <span className="text-2xl font-bold text-orange-600">{uploadProgress}%</span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-4 overflow-hidden">
                      <div
                        className="bg-gradient-to-r from-orange-500 to-red-500 h-full rounded-full transition-all duration-300"
                        style={{ width: `${uploadProgress}%` }}
                      />
                    </div>
                    <p className="text-sm text-gray-500 mt-2">No cierres esta ventana...</p>
                  </div>
                )}

                {processingStatus === 'processing' && (
                  <div className="text-center">
                    <div className="relative mb-6">
                      <Loader2 className="w-20 h-20 mx-auto mb-4 text-orange-500 animate-spin" />
                      <div className="absolute inset-0 flex items-center justify-center">
                        <span className="text-4xl">🏀</span>
                      </div>
                    </div>

                    <p className="text-2xl font-semibold text-gray-700 mb-4">Procesando tu video...</p>
                    <p className="text-sm text-gray-500 mb-6">Este proceso puede tomar unos minutos. No cierres la ventana.</p>

                    <div className="space-y-3 text-left max-w-md mx-auto">
                      <div className="flex items-center p-3 bg-green-50 rounded-lg">
                        <CheckCircle className="text-green-500 mr-3 flex-shrink-0" size={20} />
                        <span className="text-sm text-green-800">Archivo recibido y validado</span>
                      </div>
                      <div className="flex items-center p-3 bg-green-50 rounded-lg">
                        <CheckCircle className="text-green-500 mr-3 flex-shrink-0" size={20} />
                        <span className="text-sm text-green-800">Ajustando duración máxima a 30 segundos</span>
                      </div>
                      <div className="flex items-center p-3 bg-green-50 rounded-lg">
                        <CheckCircle className="text-green-500 mr-3 flex-shrink-0" size={20} />
                        <span className="text-sm text-green-800">Configurando resolución 16:9 a 720p</span>
                      </div>
                      <div className="flex items-center p-3 bg-blue-50 rounded-lg">
                        <Loader2 className="animate-spin text-blue-500 mr-3 flex-shrink-0" size={20} />
                        <span className="text-sm text-blue-800">Aplicando marca de agua ANB</span>
                      </div>
                      <div className="flex items-center p-3 bg-gray-50 rounded-lg">
                        <Clock className="text-gray-400 mr-3 flex-shrink-0" size={20} />
                        <span className="text-sm text-gray-600">Optimizando para streaming</span>
                      </div>
                    </div>

                    <div className="mt-6 p-4 bg-orange-50 border border-orange-200 rounded-xl">
                      <p className="text-sm text-orange-800">
                        <strong>Tip:</strong> Mientras esperas, puedes preparar la descripción de tu próximo video o explorar los rankings actuales.
                      </p>
                    </div>
                  </div>
                )}

                {processingStatus === 'completed' && (
                  <div className="text-center">
                    <CheckCircle className="w-20 h-20 mx-auto mb-4 text-green-500" />
                    <p className="text-3xl font-bold text-gray-800 mb-2">¡Video procesado con éxito!</p>
                    <p className="text-gray-600 mb-6">{videoIsPublic ? 'Tu video ya está disponible para votación pública' : 'Tu video privado ha sido guardado'}</p>

                    <div className={`${videoIsPublic ? 'bg-green-50 border-green-200' : 'bg-blue-50 border-blue-200'} border rounded-xl p-4 mb-6 max-w-md mx-auto`}>
                      <p className={`${videoIsPublic ? 'text-green-800' : 'text-blue-800'} text-sm`}>
                        {videoIsPublic ? (
                          <>
                            <strong>Video Público:</strong> Comparte tu video en redes sociales para conseguir más votos
                          </>
                        ) : (
                          <>
                            <strong>Video Privado:</strong> Tu video solo será visible en tu perfil personal
                          </>
                        )}
                      </p>
                    </div>

                    <div className="flex flex-col sm:flex-row gap-3 justify-center">
                      <button
                        onClick={() => {
                          resetUploadForm();
                        }}
                        className="bg-gradient-to-r from-orange-500 to-red-500 text-white px-6 py-3 rounded-full font-bold hover:shadow-lg transform hover:scale-105 transition-all"
                      >
                        Subir Otro Video
                      </button>
                      <button
                        onClick={() => setCurrentView('dashboard')}
                        className="bg-gradient-to-r from-green-500 to-emerald-500 text-white px-6 py-3 rounded-full font-bold hover:shadow-lg transform hover:scale-105 transition-all"
                      >
                        Ver mi Dashboard
                      </button>
                      {videoIsPublic && (
                        <button
                          onClick={() => setCurrentView('videos')}
                          className="bg-gradient-to-r from-blue-500 to-cyan-500 text-white px-6 py-3 rounded-full font-bold hover:shadow-lg transform hover:scale-105 transition-all"
                        >
                          Ver Videos Públicos
                        </button>
                      )}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

// Video Validation Utilities
const VIDEO_VALIDATIONS = {
  MAX_SIZE: 100 * 1024 * 1024, // 100MB in bytes
  ALLOWED_TYPES: ['video/mp4', 'video/avi', 'video/mov', 'video/quicktime'],
  ALLOWED_EXTENSIONS: ['.mp4', '.avi', '.mov']
};

const validateVideoFile = (file) => {
  const errors = [];

  if (!file) {
    errors.push('Por favor selecciona un archivo de video');
    return { isValid: false, errors };
  }

  // Check file size (100MB max)
  if (file.size > VIDEO_VALIDATIONS.MAX_SIZE) {
    const sizeInMB = (file.size / (1024 * 1024)).toFixed(1);
    errors.push(`El archivo es demasiado grande (${sizeInMB}MB). El tamaño máximo permitido es 100MB`);
  }

  // Check file type
  const fileName = file.name.toLowerCase();
  const hasValidExtension = VIDEO_VALIDATIONS.ALLOWED_EXTENSIONS.some(ext => fileName.endsWith(ext));
  const hasValidType = VIDEO_VALIDATIONS.ALLOWED_TYPES.includes(file.type);

  if (!hasValidExtension && !hasValidType) {
    errors.push('Formato de archivo no válido. Solo se permiten archivos MP4, AVI y MOV');
  }

  // Additional checks for file integrity
  if (file.size === 0) {
    errors.push('El archivo está vacío o dañado');
  }

  return {
    isValid: errors.length === 0,
    errors,
    fileInfo: {
      name: file.name,
      size: file.size,
      sizeFormatted: (file.size / (1024 * 1024)).toFixed(2) + ' MB',
      type: file.type
    }
  };
};

// API Service
const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080';

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

      // Handle null responses from empty collections
      return data === null ? [] : data;
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

  async getProfile() {
    const response = await this.request('/api/auth/profile');
    return response;
  }

  async uploadVideo(title, file, isPublic = false) {
    const formData = new FormData();
    formData.append('title', title);
    formData.append('video_file', file);
    formData.append('is_public', isPublic.toString());

    const response = await fetch(`${this.baseURL}/api/videos/upload`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.token}`,
      },
      body: formData,
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

  async getPublicVideos() {
    return await this.request('/api/public/videos');
  }

  async voteVideo(videoId) {
    return await this.request(`/api/public/videos/${videoId}/vote`, {
      method: 'POST',
    });
  }

  async getTopRankings(limit = 10, city = '') {
    const params = new URLSearchParams();
    if (limit) params.append('limit', limit);
    if (city && city !== 'todas') params.append('city', city);

    const query = params.toString() ? `?${params.toString()}` : '';
    return await this.request(`/api/public/rankings${query}`);
  }

  async getUserVotes() {
    return await this.request('/api/user/votes');
  }

  logout() {
    this.token = null;
    localStorage.removeItem('access_token');
  }

  isAuthenticated() {
    return !!this.token;
  }
}

const apiService = new ApiService();

const App = () => {
  const [currentView, setCurrentView] = useState('landing');
  const [user, setUser] = useState(null);
  const [selectedCity, setSelectedCity] = useState('todas');
  const [videos, setVideos] = useState([]);
  const [rankings, setRankings] = useState([]);
  const [myVideos, setMyVideos] = useState([]);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [processingStatus, setProcessingStatus] = useState(null);
  const [isPrivate, setIsPrivate] = useState(false);
  const [loading, setLoading] = useState(false);
  const [votedVideos, setVotedVideos] = useState(new Set());
  const [videoIsPublic, setVideoIsPublic] = useState(false);

  // Estados para upload de video
  const [selectedFile, setSelectedFile] = useState(null);
  const [videoTitle, setVideoTitle] = useState('');
  const [uploading, setUploading] = useState(false);
  const [dragActive, setDragActive] = useState(false);
  const [uploadError, setUploadError] = useState('');

  const cities = ['Todas', 'Bogotá', 'Medellín', 'Cali', 'Barranquilla', 'Cartagena', 'Bucaramanga', 'Pereira', 'Manizales', 'Santa Marta'];

  // Función para resetear todos los estados del formulario de upload
  const resetUploadForm = () => {
    setSelectedFile(null);
    setVideoTitle('');
    setVideoIsPublic(false);
    setProcessingStatus(null);
    setUploadProgress(0);
    setUploading(false);
    setUploadError('');
  };

  // Check for existing auth on app load
  useEffect(() => {
    const checkAuth = async () => {
      if (apiService.isAuthenticated()) {
        try {
          const profile = await apiService.getProfile();
          setUser(profile);
          setCurrentView('dashboard');
        } catch (error) {
          console.error('Auth check failed:', error);
          apiService.logout();
        }
      }
    };
    checkAuth();
  }, []);

  // Load data based on current view
  useEffect(() => {
    const loadData = async () => {
      setLoading(true);
      try {
        if (currentView === 'videos' || currentView === 'dashboard') {
          try {
            const publicVideos = await apiService.getPublicVideos();
            setVideos(Array.isArray(publicVideos) ? publicVideos : (publicVideos ? [publicVideos] : []));
          } catch (error) {
            console.warn('Failed to load public videos:', error);
            setVideos([]);
          }
        }

        if (currentView === 'rankings' || currentView === 'dashboard') {
          try {
            const topRankings = await apiService.getTopRankings(50, selectedCity);
            setRankings(Array.isArray(topRankings) ? topRankings : (topRankings ? [topRankings] : []));
          } catch (error) {
            console.warn('Failed to load rankings:', error);
            setRankings([]);
          }
        }

        if (currentView === 'dashboard' && user) {
          try {
            const userVideos = await apiService.getMyVideos();
            setMyVideos(Array.isArray(userVideos) ? userVideos : (userVideos ? [userVideos] : []));
          } catch (error) {
            console.warn('Failed to load user videos:', error);
            setMyVideos([]);
          }
        }

        // Load user votes if authenticated
        if (user && (currentView === 'videos' || currentView === 'dashboard')) {
          try {
            const userVotes = await apiService.getUserVotes();
            setVotedVideos(new Set(Array.isArray(userVotes) ? userVotes : []));
          } catch (error) {
            console.warn('Failed to load user votes:', error);
            setVotedVideos(new Set());
          }
        }
      } catch (error) {
        console.error('Failed to load data:', error);
        setVideos([]);
        setRankings([]);
        setMyVideos([]);
      } finally {
        setLoading(false);
      }
    };

    if (currentView !== 'landing' && currentView !== 'login') {
      loadData();
    }
  }, [currentView, selectedCity, user]);

  // Componente de navegación principal
  const Navigation = () => (
    <nav className="bg-gradient-to-r from-orange-600 via-red-600 to-orange-600 text-white shadow-2xl sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <div className="flex justify-between items-center">
          <div
            className="flex items-center space-x-3 cursor-pointer group"
            onClick={() => setCurrentView('landing')}
          >
            <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center group-hover:scale-110 transition-transform">
              <span className="text-2xl">🏀</span>
            </div>
            <div>
              <h1 className="text-2xl font-bold">ANB Rising Stars</h1>
              <p className="text-xs opacity-90">Showcase 2025</p>
            </div>
          </div>

          <div className="flex items-center space-x-4 md:space-x-6">
            {user && (
              <>
                <button
                  onClick={() => setCurrentView('dashboard')}
                  className="hover:text-orange-200 transition-colors flex items-center space-x-1"
                >
                  <Home size={20} />
                  <span className="hidden md:inline">Inicio</span>
                </button>
                <button
                  onClick={() => setCurrentView('upload')}
                  className="hover:text-orange-200 transition-colors flex items-center space-x-1"
                >
                  <Upload size={20} />
                  <span className="hidden md:inline">Subir</span>
                </button>
                <button
                  onClick={() => setCurrentView('videos')}
                  className="hover:text-orange-200 transition-colors flex items-center space-x-1"
                >
                  <Video size={20} />
                  <span className="hidden md:inline">Videos</span>
                </button>
                <button
                  onClick={() => setCurrentView('rankings')}
                  className="hover:text-orange-200 transition-colors flex items-center space-x-1"
                >
                  <Trophy size={20} />
                  <span className="hidden md:inline">Rankings</span>
                </button>
              </>
            )}

            {user ? (
              <div className="flex items-center space-x-3">
                <button
                  onClick={() => setCurrentView('profile')}
                  className="flex items-center space-x-2 hover:text-orange-200"
                >
                  <div className="w-8 h-8 bg-white/20 rounded-full flex items-center justify-center">
                    <User size={16} />
                  </div>
                  <span className="hidden md:inline text-sm">{user.first_name}</span>
                </button>
                <button
                  onClick={() => {
                    apiService.logout();
                    setUser(null);
                    setVotedVideos(new Set()); // Clear voted videos on logout
                    setCurrentView('landing');
                  }}
                  className="bg-white/20 backdrop-blur p-2 rounded-full hover:bg-white/30 transition-colors"
                >
                  <LogOut size={18} />
                </button>
              </div>
            ) : (
              <button
                onClick={() => setCurrentView('login')}
                className="bg-white text-orange-600 px-6 py-2 rounded-full font-bold hover:bg-orange-50 transition-all transform hover:scale-105 shadow-lg"
              >
                Iniciar Sesión
              </button>
            )}
          </div>
        </div>
      </div>
    </nav>
  );

  // Landing Page mejorada
  const LandingPage = () => {
    const [activeFeature, setActiveFeature] = useState(0);
    const features = [
      { icon: Upload, title: 'Sube tu Video', desc: 'Muestra tus mejores jugadas en 30 segundos' },
      { icon: Users, title: 'Votación Pública', desc: 'El público decide quiénes son los mejores' },
      { icon: Award, title: 'Clasificación', desc: 'Los más votados de cada ciudad clasifican' },
      { icon: Star, title: 'Showcase Final', desc: 'Compite frente a cazatalentos profesionales' }
    ];

    return (
      <div className="min-h-screen bg-gradient-to-br from-orange-600 to-orange-400">
        <div className="relative">
          <div className="absolute inset-0 bg-black/40"></div>

          <div className="relative max-w-7xl mx-auto px-4 py-16 md:py-24">
            <div className="text-center text-white">
              <div className="mb-8">
                <h1 className="text-5xl md:text-7xl lg:text-8xl font-black mb-4 animate-pulse">
                  RISING STARS
                </h1>
                <div className="text-3xl md:text-5xl lg:text-6xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-orange-400 to-yellow-400">
                  SHOWCASE 2025
                </div>
              </div>

              <p className="text-lg md:text-xl lg:text-2xl mb-12 opacity-90 max-w-3xl mx-auto leading-relaxed">
                ¿Tienes lo que se necesita para ser la próxima estrella del baloncesto nacional?
                Demuestra tu talento y compite por un lugar en el torneo más importante del año.
              </p>

              <div className="flex flex-col sm:flex-row gap-4 justify-center mb-16">
                <button
                  onClick={() => setCurrentView('login')}
                  className="group bg-gradient-to-r from-orange-500 to-red-500 text-white px-8 py-4 rounded-full text-lg font-bold shadow-2xl transform transition-all duration-300 hover:scale-110 hover:shadow-orange-500/50"
                >
                  <Play className="inline mr-2 group-hover:animate-pulse" />
                  Comenzar Ahora
                </button>
                <button
                  onClick={() => setCurrentView('rankings')}
                  className="group bg-white text-gray-900 px-8 py-4 rounded-full text-lg font-bold shadow-2xl transform transition-all duration-300 hover:scale-110"
                >
                  <Trophy className="inline mr-2 group-hover:animate-bounce" />
                  Ver Rankings
                </button>
              </div>

              <div className="grid md:grid-cols-4 gap-6 mt-16">
                {features.map((feature, index) => {
                  const Icon = feature.icon;
                  return (
                    <div
                      key={index}
                      onMouseEnter={() => setActiveFeature(index)}
                      className={`bg-white/10 backdrop-blur-lg rounded-2xl p-6 transform transition-all duration-500 cursor-pointer ${activeFeature === index ? 'scale-110 bg-white/20' : 'hover:scale-105'
                        }`}
                    >
                      <Icon className="w-12 h-12 text-orange-400 mx-auto mb-4" />
                      <h3 className="text-xl font-bold mb-2">{feature.title}</h3>
                      <p className="opacity-80 text-sm">{feature.desc}</p>
                    </div>
                  );
                })}
              </div>

              <div className="mt-16 p-8 bg-white/10 backdrop-blur-lg rounded-3xl">
                <h2 className="text-3xl font-bold mb-6">🏆 Premios y Beneficios</h2>
                <div className="grid md:grid-cols-3 gap-6 text-left">
                  <div className="bg-white/10 rounded-xl p-4">
                    <h3 className="font-bold text-lg mb-2 text-orange-400">Exposición Nacional</h3>
                    <p className="text-sm opacity-80">Muéstrate ante cazatalentos de equipos profesionales</p>
                  </div>
                  <div className="bg-white/10 rounded-xl p-4">
                    <h3 className="font-bold text-lg mb-2 text-orange-400">Entrenamiento Elite</h3>
                    <p className="text-sm opacity-80">Acceso a sesiones con entrenadores profesionales</p>
                  </div>
                  <div className="bg-white/10 rounded-xl p-4">
                    <h3 className="font-bold text-lg mb-2 text-orange-400">Contratos Profesionales</h3>
                    <p className="text-sm opacity-80">Oportunidad de firmar con equipos de la liga</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  };

  // Sistema de Login/Registro mejorado
  const LoginView = () => {
    const [isLogin, setIsLogin] = useState(true);
    const [formLoading, setFormLoading] = useState(false);
    const [error, setError] = useState('');
    const [formData, setFormData] = useState({
      email: '',
      password: '',
      firstName: '',
      lastName: '',
      city: '',
      country: 'Colombia',
      confirmPassword: ''
    });

    const handleSubmit = async () => {
      setFormLoading(true);
      setError('');

      try {
        if (isLogin) {
          await apiService.login(formData.email, formData.password);
          const profile = await apiService.getProfile();
          setUser(profile);
          setCurrentView('dashboard');
        } else {
          if (formData.password !== formData.confirmPassword) {
            setError('Passwords do not match');
            return;
          }

          await apiService.signup(formData);
          await apiService.login(formData.email, formData.password);
          const profile = await apiService.getProfile();
          setUser(profile);
          setCurrentView('dashboard');
        }
      } catch (err) {
        setError(err.message || 'An error occurred');
      } finally {
        setFormLoading(false);
      }
    };

    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-orange-900 flex items-center justify-center p-4">
        <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md overflow-hidden">
          <div className="bg-gradient-to-r from-orange-500 to-red-500 p-6 text-white">
            <h2 className="text-3xl font-bold text-center">
              {isLogin ? 'Bienvenido de vuelta' : 'Únete a Rising Stars'}
            </h2>
            <p className="text-center mt-2 opacity-90">
              {isLogin ? 'Ingresa para ver tu progreso' : 'Comienza tu camino al estrellato'}
            </p>
          </div>

          <div className="p-8 space-y-4">
            {error && (
              <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl">
                {error}
              </div>
            )}

            {!isLogin && (
              <>
                <div className="grid grid-cols-2 gap-3">
                  <input
                    type="text"
                    placeholder="Nombre *"
                    required={!isLogin}
                    className="p-3 border-2 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                    value={formData.firstName}
                    onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
                  />
                  <input
                    type="text"
                    placeholder="Apellido *"
                    required={!isLogin}
                    className="p-3 border-2 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                    value={formData.lastName}
                    onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                  />
                </div>

                <select
                  className="w-full p-3 border-2 rounded-xl focus:ring-2 focus:ring-orange-500 transition-all"
                  value={formData.city}
                  required={!isLogin}
                  onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                >
                  <option value="">Selecciona tu ciudad *</option>
                  {cities.slice(1).map(city => (
                    <option key={city} value={city}>{city}</option>
                  ))}
                </select>
              </>
            )}

            <input
              type="email"
              placeholder="Correo electrónico *"
              required
              className="w-full p-3 border-2 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            />

            <input
              type="password"
              placeholder="Contraseña *"
              required
              className="w-full p-3 border-2 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
            />

            {!isLogin && (
              <>
                <input
                  type="password"
                  placeholder="Confirmar contraseña *"
                  required={!isLogin}
                  className="w-full p-3 border-2 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                  value={formData.confirmPassword}
                  onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
                />

                <div className="flex items-start space-x-2 text-sm text-gray-600">
                  <input type="checkbox" className="mt-1" />
                  <p>Acepto los términos y condiciones y autorizo el uso de mi imagen para fines promocionales del torneo</p>
                </div>
              </>
            )}

            <button
              onClick={handleSubmit}
              disabled={formLoading}
              className="w-full bg-gradient-to-r from-orange-500 to-red-500 text-white py-3 rounded-xl font-bold shadow-lg transform transition-all hover:scale-105 hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {formLoading ? 'Cargando...' : (isLogin ? 'Ingresar' : 'Crear Cuenta')}
            </button>
          </div>

          <div className="pb-6 text-center">
            <p className="text-gray-600">
              {isLogin ? '¿No tienes cuenta?' : '¿Ya tienes cuenta?'}
              <button
                onClick={() => setIsLogin(!isLogin)}
                className="text-orange-600 font-bold ml-2 hover:underline"
              >
                {isLogin ? 'Regístrate' : 'Inicia Sesión'}
              </button>
            </p>
          </div>
        </div>
      </div>
    );
  };

  // Dashboard mejorado
  const Dashboard = () => {
    const totalVotes = myVideos.reduce((sum, video) => sum + (video.votes || 0), 0);
    const processedVideos = myVideos.filter(v => v.status === 'processed').length;
    const userRanking = rankings.findIndex(r => r.username === `${user?.first_name} ${user?.last_name}`) + 1;

    const stats = [
      { label: 'Votos Totales', value: totalVotes.toLocaleString(), change: '+' + Math.floor(totalVotes * 0.15), icon: ThumbsUp, color: 'from-orange-500 to-red-500' },
      { label: 'Ranking Ciudad', value: userRanking > 0 ? `#${userRanking}` : '-', change: userRanking > 0 ? '↑ 3' : '', icon: Trophy, color: 'from-purple-500 to-pink-500' },
      { label: 'Videos Procesados', value: processedVideos, change: `+${myVideos.length - processedVideos} pendientes`, icon: Video, color: 'from-blue-500 to-cyan-500' },
      { label: 'Días Restantes', value: '14', change: '', icon: Calendar, color: 'from-green-500 to-emerald-500' }
    ];

    return (
      <div className="min-h-screen bg-gray-50 p-4">
        <div className="max-w-7xl mx-auto">
          <div className="mb-8">
            <h1 className="text-4xl font-bold text-gray-800 mb-2">
              Hola, {user?.first_name} 👋
            </h1>
            <p className="text-gray-600">Este es tu panel de control para Rising Stars Showcase 2025</p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {stats.map((stat, index) => {
              const Icon = stat.icon;
              return (
                <div
                  key={index}
                  className="bg-white rounded-2xl shadow-lg overflow-hidden transform hover:scale-105 transition-all"
                >
                  <div className={`h-2 bg-gradient-to-r ${stat.color}`}></div>
                  <div className="p-6">
                    <div className="flex items-start justify-between mb-4">
                      <Icon className="w-8 h-8 text-gray-400" />
                      {stat.change && (
                        <span className={`text-sm font-bold ${stat.change.includes('+') || stat.change.includes('↑') ? 'text-green-500' : 'text-gray-500'}`}>
                          {stat.change}
                        </span>
                      )}
                    </div>
                    <div className="text-3xl font-bold text-gray-800 mb-1">{stat.value}</div>
                    <div className="text-sm text-gray-600">{stat.label}</div>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="grid lg:grid-cols-3 gap-6">
            <div className="lg:col-span-2 bg-white rounded-2xl shadow-lg p-6">
              <h3 className="text-xl font-bold mb-4 text-gray-800 flex items-center">
                <Video className="mr-2" />
                Mis Videos de Competencia
              </h3>

              {myVideos.length > 0 ? (
                <div className="space-y-4">
                  {myVideos.slice(0, 3).map(video => (
                    <div key={video.video_id} className="bg-gradient-to-br from-gray-900 to-gray-700 rounded-xl p-4 relative overflow-hidden group">
                      <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
                      <div className="relative z-10 text-white">
                        <div className="flex items-center justify-between mb-2">
                          <h4 className="text-lg font-semibold truncate">{video.title}</h4>
                          <span className={`px-3 py-1 rounded-full text-xs font-bold ${video.status === 'processed' ? 'bg-green-500' :
                              video.status === 'processing' ? 'bg-yellow-500' :
                                video.status === 'uploaded' ? 'bg-blue-500' : 'bg-red-500'
                            }`}>
                            {video.status === 'processed' ? 'COMPLETADO' :
                              video.status === 'processing' ? 'PROCESANDO' :
                                video.status === 'uploaded' ? 'CARGADO' : 'ERROR'}
                          </span>
                        </div>
                        <div className="flex items-center justify-between text-sm">
                          <span>Votos: {video.votes || 0}</span>
                          <span>Subido: {new Date(video.uploaded_at).toLocaleDateString()}</span>
                        </div>
                      </div>
                    </div>
                  ))}

                  {myVideos.length > 3 && (
                    <button
                      onClick={() => setCurrentView('profile')}
                      className="w-full text-center py-3 text-orange-600 hover:text-orange-700 font-semibold"
                    >
                      Ver todos mis videos ({myVideos.length})
                    </button>
                  )}
                </div>
              ) : (
                <div className="text-center py-8">
                  <Upload className="w-16 h-16 mx-auto text-gray-300 mb-4" />
                  <h4 className="text-lg font-semibold text-gray-600 mb-2">¡Sube tu primer video!</h4>
                  <p className="text-gray-500 mb-4">Muestra tus mejores jugadas y comienza a competir</p>
                  <button
                    onClick={() => setCurrentView('upload')}
                    className="bg-gradient-to-r from-orange-500 to-red-500 text-white px-6 py-3 rounded-full font-bold hover:shadow-lg transform hover:scale-105 transition-all"
                  >
                    Subir Video
                  </button>
                </div>
              )}
            </div>

            <div className="bg-white rounded-2xl shadow-lg p-6">
              <h3 className="text-xl font-bold mb-4 text-gray-800 flex items-center">
                <BarChart3 className="mr-2" />
                Tu Progreso
              </h3>
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between text-sm mb-1">
                    <span className="text-gray-600">Objetivo de votos</span>
                    <span className="font-bold">{totalVotes} / 3,000</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
                    <div className="bg-gradient-to-r from-orange-500 to-red-500 h-full rounded-full transition-all"
                      style={{ width: `${Math.min((totalVotes / 3000) * 100, 100)}%` }}></div>
                  </div>
                </div>

                <div className="pt-4 border-t">
                  <p className="text-sm text-gray-600 mb-3">Posición en tu ciudad</p>
                  <div className="flex items-center justify-between">
                    <div className="text-2xl font-bold text-orange-600">
                      {userRanking > 0 ? `#${userRanking}` : '-'}
                    </div>
                    <div className="text-sm text-gray-500">de {rankings.length} participantes</div>
                  </div>
                </div>

                <div className="pt-4 border-t">
                  <p className="text-sm text-gray-600 mb-2">Compartir para más votos:</p>
                  <div className="flex space-x-2">
                    <button className="flex-1 bg-blue-500 text-white py-2 rounded-lg text-sm hover:bg-blue-600 transition-colors">
                      Facebook
                    </button>
                    <button className="flex-1 bg-black text-white py-2 rounded-lg text-sm hover:bg-gray-800 transition-colors">
                      X
                    </button>
                    <button className="flex-1 bg-gradient-to-r from-purple-500 to-pink-500 text-white py-2 rounded-lg text-sm hover:opacity-90 transition-opacity">
                      Instagram
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="mt-8 bg-white rounded-2xl shadow-lg p-6">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold text-gray-800">Videos Destacados para Votar</h3>
              <button
                onClick={() => setCurrentView('videos')}
                className="text-orange-600 hover:text-orange-700 font-semibold flex items-center"
              >
                Ver todos
                <ChevronRight className="ml-1" size={20} />
              </button>
            </div>
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {videos
                .filter(video => {
                  const isPublic = video.is_public === true || video.is_public === 'true';
                  const isOtherUser = video.user_id !== user?.id;
                  return isPublic && isOtherUser;
                })
                .slice(0, 3)
                .map(video => (
                  <VideoCard key={video.video_id} video={video} />
                ))}
            </div>
            {videos.filter(video => {
              const isPublic = video.is_public === true || video.is_public === 'true';
              const isOtherUser = video.user_id !== user?.id;
              return isPublic && isOtherUser;
            }).length === 0 && (
                <div className="text-center py-8">
                  <Video className="w-12 h-12 mx-auto text-gray-400 mb-3" />
                  <p className="text-gray-500">No hay videos públicos de otros usuarios disponibles para votar</p>
                </div>
              )}
          </div>
        </div>
      </div>
    );
  };


  // Vista de todos los videos
  const VideosView = () => {
    const [filteredVideos, setFilteredVideos] = useState([]);
    const [selectedCityFilter, setSelectedCityFilter] = useState('todas');

    // Filtrar videos cuando cambie la ciudad seleccionada o los videos
    useEffect(() => {
      if (selectedCityFilter === 'todas') {
        setFilteredVideos(videos);
      } else {
        const filtered = videos.filter(video =>
          video.user_city && video.user_city.toLowerCase() === selectedCityFilter.toLowerCase()
        );
        setFilteredVideos(filtered);
      }
    }, [selectedCityFilter, videos]);

    return (
      <div className="min-h-screen bg-gray-50 p-4">
        <div className="max-w-7xl mx-auto">
          <h2 className="text-4xl font-bold mb-8 text-gray-800">Videos de Competencia</h2>
          <p className="text-gray-600 mb-6">Vota por los mejores videos y ayuda a determinar a los finalistas</p>

          <div className="mb-6 flex flex-wrap gap-2">
            <div className="flex items-center space-x-2 text-sm text-gray-600 mr-4">
              <Filter size={16} />
              <span>Filtrar por ciudad:</span>
            </div>
            {cities.map(city => (
              <button
                key={city}
                onClick={() => setSelectedCityFilter(city.toLowerCase())}
                className={`px-5 py-2 rounded-full font-semibold transition-all ${selectedCityFilter === city.toLowerCase()
                    ? 'bg-gradient-to-r from-orange-500 to-red-500 text-white shadow-lg'
                    : 'bg-white text-gray-700 hover:bg-orange-50 shadow'
                  }`}
              >
                {city}
              </button>
            ))}
          </div>

          {loading ? (
            <div className="flex items-center justify-center h-64">
              <Loader2 className="w-8 h-8 animate-spin text-orange-500" />
              <div className="ml-3 text-gray-600">Cargando videos...</div>
            </div>
          ) : (
            <>
              <div className="mb-4 text-sm text-gray-600">
                Mostrando {filteredVideos.length} video{filteredVideos.length !== 1 ? 's' : ''}
                {selectedCityFilter !== 'todas' && ` de ${cities.find(c => c.toLowerCase() === selectedCityFilter)}`}
              </div>
              <div className="grid md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                {filteredVideos.map(video => (
                  <VideoCard key={video.video_id} video={video} detailed />
                ))}
              </div>
            </>
          )}

          {!loading && filteredVideos.length === 0 && videos.length > 0 && (
            <div className="text-center py-12">
              <Video className="w-16 h-16 mx-auto text-gray-400 mb-4" />
              <h3 className="text-xl font-semibold text-gray-600 mb-2">
                No hay videos en {cities.find(c => c.toLowerCase() === selectedCityFilter)}
              </h3>
              <p className="text-gray-500">Intenta seleccionar otra ciudad o ver todos los videos</p>
            </div>
          )}

          {!loading && videos.length === 0 && (
            <div className="text-center py-12">
              <Video className="w-16 h-16 mx-auto text-gray-400 mb-4" />
              <h3 className="text-xl font-semibold text-gray-600 mb-2">No hay videos disponibles</h3>
              <p className="text-gray-500">¡Sé el primero en subir un video!</p>
            </div>
          )}
        </div>
      </div>
    );
  };

  // Rankings mejorado
  const Rankings = () => (
    <div className="min-h-screen bg-gray-50 p-4">
      <div className="max-w-6xl mx-auto">
        <div className="mb-8">
          <h2 className="text-4xl font-bold text-gray-800 mb-2">Rankings Rising Stars 2025</h2>
          <p className="text-gray-600">Los mejores jugadores de cada ciudad competirán en el Showcase final</p>
        </div>

        <div className="mb-6 flex flex-wrap gap-2">
          {cities.map(city => (
            <button
              key={city}
              onClick={() => setSelectedCity(city.toLowerCase())}
              className={`px-5 py-2 rounded-full font-semibold transition-all ${selectedCity === city.toLowerCase()
                  ? 'bg-gradient-to-r from-orange-500 to-red-500 text-white shadow-lg'
                  : 'bg-white text-gray-700 hover:bg-orange-50 shadow'
                }`}
            >
              {city}
            </button>
          ))}
        </div>

        <div className="bg-white rounded-2xl shadow-xl overflow-hidden">
          <div className="bg-gradient-to-r from-orange-500 via-red-500 to-orange-500 p-6 text-white">
            <h3 className="text-2xl font-bold">
              Top Jugadores {selectedCity !== 'todas' ? `- ${selectedCity.charAt(0).toUpperCase() + selectedCity.slice(1)}` : 'Nacional'}
            </h3>
            <p className="text-sm opacity-90 mt-1">Actualizado en tiempo real</p>
          </div>

          <div className="divide-y divide-gray-100">
            {loading ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="w-8 h-8 animate-spin text-orange-500" />
              </div>
            ) : rankings.length > 0 ? (
              rankings.map((player, index) => (
                <div key={player.video_id} className="p-6 hover:bg-gray-50 transition-all group">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-4">
                      <div className={`text-3xl font-black ${index === 0 ? 'text-yellow-500' : index === 1 ? 'text-gray-400' : index === 2 ? 'text-orange-600' : 'text-gray-300'}`}>
                        {index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : `#${index + 1}`}
                      </div>
                      <div className="w-16 h-16 bg-gradient-to-br from-orange-400 to-red-400 rounded-full flex items-center justify-center text-2xl shadow-lg group-hover:scale-110 transition-transform text-white font-bold">
                        {player.username ? player.username.charAt(0).toUpperCase() : '?'}
                      </div>
                      <div>
                        <h4 className="text-xl font-bold text-gray-800">{player.username}</h4>
                        <div className="flex items-center space-x-4 text-sm text-gray-600 mt-1">
                          <span className="flex items-center">
                            <MapPin size={14} className="mr-1" />
                            {player.city}
                          </span>
                          <span className="bg-gray-100 px-2 py-0.5 rounded-full">{player.title}</span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center space-x-6">
                      <div className="text-right">
                        <div className="text-3xl font-bold text-gray-800">{(player.votes || 0).toLocaleString()}</div>
                        <div className="text-sm text-gray-500">votos</div>
                      </div>

                      <button className="bg-gradient-to-r from-orange-500 to-red-500 text-white px-6 py-2 rounded-full font-semibold hover:shadow-lg transform hover:scale-105 transition-all">
                        Ver Video
                      </button>
                    </div>
                  </div>

                  {index < 3 && (
                    <div className="mt-4 pt-4 border-t border-gray-100">
                      <div className="flex items-center justify-between text-sm">
                        <span className="text-gray-500">Clasificado para el Showcase Final</span>
                        <span className="text-green-600 font-semibold flex items-center">
                          <CheckCircle size={16} className="mr-1" />
                          Confirmado
                        </span>
                      </div>
                    </div>
                  )}
                </div>
              ))
            ) : (
              <div className="p-12 text-center">
                <Trophy className="w-16 h-16 mx-auto text-gray-400 mb-4" />
                <h3 className="text-xl font-semibold text-gray-600 mb-2">No hay rankings disponibles</h3>
                <p className="text-gray-500">Los rankings aparecerán cuando haya videos con votos.</p>
              </div>
            )}
          </div>
        </div>

        <div className="mt-8 bg-gradient-to-r from-orange-100 to-red-100 rounded-2xl p-6">
          <h3 className="text-lg font-bold text-gray-800 mb-2">📊 Estadísticas de Votación</h3>
          <div className="grid md:grid-cols-4 gap-4 text-center">
            <div>
              <div className="text-2xl font-bold text-orange-600">{rankings.reduce((sum, r) => sum + (r.votes || 0), 0).toLocaleString()}</div>
              <div className="text-sm text-gray-600">Votos totales</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-purple-600">{rankings.length}</div>
              <div className="text-sm text-gray-600">Participantes</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-blue-600">{cities.length - 1}</div>
              <div className="text-sm text-gray-600">Ciudades activas</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-green-600">14</div>
              <div className="text-sm text-gray-600">Días restantes</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );

  // Perfil 
  const Profile = () => (
    <div className="min-h-screen bg-gray-50 p-4">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-2xl shadow-xl overflow-hidden">
          <div className="bg-gradient-to-r from-orange-500 to-red-500 h-32"></div>
          <div className="px-8 pb-8">
            <div className="flex items-end -mt-16 mb-6">
              <div className="w-32 h-32 bg-white rounded-full border-4 border-white shadow-xl flex items-center justify-center text-5xl">
                🏀
              </div>
              <div className="ml-6 mb-4">
                <h2 className="text-3xl font-bold text-gray-800">{user?.first_name} {user?.last_name}</h2>
                <p className="text-gray-600">{user?.email}</p>
                <div className="flex items-center space-x-3 mt-2">
                  <span className="bg-orange-100 text-orange-700 px-3 py-1 rounded-full text-sm font-semibold">
                    {user?.city}
                  </span>
                  <span className="bg-blue-100 text-blue-700 px-3 py-1 rounded-full text-sm font-semibold">
                    {user?.country}
                  </span>
                  <span className="bg-green-100 text-green-700 px-3 py-1 rounded-full text-sm font-semibold flex items-center">
                    <CheckCircle size={14} className="mr-1" />
                    Verificado
                  </span>
                </div>
              </div>
            </div>

            <div className="grid md:grid-cols-4 gap-4 mb-8">
              <div className="bg-gradient-to-br from-orange-50 to-red-50 rounded-xl p-4 text-center">
                <div className="text-3xl font-bold text-orange-600">
                  {myVideos.reduce((sum, video) => sum + (video.votes || 0), 0)}
                </div>
                <div className="text-sm text-gray-600">Votos totales</div>
              </div>
              <div className="bg-gradient-to-br from-purple-50 to-pink-50 rounded-xl p-4 text-center">
                <div className="text-3xl font-bold text-purple-600">
                  #{rankings.findIndex(r => r.username === `${user?.first_name} ${user?.last_name}`) + 1 || '-'}
                </div>
                <div className="text-sm text-gray-600">Ranking ciudad</div>
              </div>
              <div className="bg-gradient-to-br from-blue-50 to-cyan-50 rounded-xl p-4 text-center">
                <div className="text-3xl font-bold text-blue-600">{myVideos.length}</div>
                <div className="text-sm text-gray-600">Videos subidos</div>
              </div>
              <div className="bg-gradient-to-br from-green-50 to-emerald-50 rounded-xl p-4 text-center">
                <div className="text-3xl font-bold text-green-600">
                  {myVideos.filter(v => v.status === 'processed').length}
                </div>
                <div className="text-sm text-gray-600">Videos procesados</div>
              </div>
            </div>

            <div className="space-y-6">
              <div className="border rounded-xl p-6">
                <h3 className="text-xl font-bold mb-4 text-gray-800 flex items-center">
                  <Video className="mr-2" />
                  Mis Videos de Competencia
                </h3>
                {myVideos.length > 0 ? (
                  <div className="space-y-3">
                    {myVideos.map(video => (
                      <div key={video.video_id} className="bg-gray-50 rounded-xl p-4">
                        <div className="flex items-center justify-between">
                          <div>
                            <h4 className="font-semibold text-gray-800">{video.title}</h4>
                            <p className="text-sm text-gray-600">
                              Subido: {new Date(video.uploaded_at).toLocaleDateString()}
                            </p>
                          </div>
                          <div className="flex items-center space-x-3">
                            <span className={`px-2 py-1 rounded-full text-xs font-medium ${video.status === 'processed' ? 'bg-green-100 text-green-800' :
                                video.status === 'processing' ? 'bg-yellow-100 text-yellow-800' :
                                  video.status === 'uploaded' ? 'bg-blue-100 text-blue-800' :
                                    'bg-red-100 text-red-800'
                              }`}>
                              {video.status === 'processed' ? 'Procesado' :
                                video.status === 'processing' ? 'Procesando' :
                                  video.status === 'uploaded' ? 'Subido' : 'Error'}
                            </span>
                            <span className="text-sm font-bold text-gray-700">{video.votes || 0} votos</span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-center py-8">
                    <Upload className="w-16 h-16 mx-auto text-gray-300 mb-4" />
                    <h4 className="text-lg font-semibold text-gray-600 mb-2">¡Sube tu primer video!</h4>
                    <p className="text-gray-500 mb-4">Muestra tus mejores jugadas y comienza a competir</p>
                    <button
                      onClick={() => setCurrentView('upload')}
                      className="bg-gradient-to-r from-orange-500 to-red-500 text-white px-6 py-3 rounded-full font-bold hover:shadow-lg transform hover:scale-105 transition-all"
                    >
                      Subir Video
                    </button>
                  </div>
                )}
              </div>


            </div>
          </div>
        </div>
      </div>
    </div>
  );

  // Componente de tarjeta de video
  const VideoCard = ({ video, detailed = false }) => {
    const [voted, setVoted] = useState(votedVideos.has(video.video_id));
    const [isPlaying, setIsPlaying] = useState(false);
    const [voteError, setVoteError] = useState('');
    const [localVoteCount, setLocalVoteCount] = useState(video.votes || 0);
    const [isVoting, setIsVoting] = useState(false);

    // Actualizar estado de videos votados
    useEffect(() => {
      setVoted(votedVideos.has(video.video_id));
    }, [votedVideos, video.video_id]);

    const handleVote = async () => {
      if (!user) {
        setVoteError('Debes iniciar sesión para votar');
        return;
      }

      if (voted || isVoting) {
        setVoteError('Ya has votado por este video');
        return;
      }

      if (video.status !== 'processed') {
        setVoteError('El video aún está en procesamiento');
        return;
      }

      // Prevenir double-click 
      setIsVoting(true);
      setVoted(true);
      setVotedVideos(new Set([...votedVideos, video.video_id]));
      setLocalVoteCount(prev => prev + 1);

      try {
        setVoteError('');
        const result = await apiService.voteVideo(video.video_id);

      } catch (error) {
        console.error('Vote failed:', error);

        setVoted(false);
        const newVotedSet = new Set(votedVideos);
        newVotedSet.delete(video.video_id);
        setVotedVideos(newVotedSet);
        setLocalVoteCount(prev => Math.max(0, prev - 1));

        if (error.message.includes('400')) {
          setVoteError('Ya has votado por este video');
        } else if (error.message.includes('404')) {
          setVoteError('Video no encontrado');
        } else if (error.message.includes('401')) {
          setVoteError('Debes iniciar sesión para votar');
        } else {
          setVoteError('Error al votar. Intenta de nuevo.');
        }
      } finally {
        setIsVoting(false);
      }
    };

    return (
      <div className="bg-white rounded-xl shadow-lg overflow-hidden transform hover:scale-105 transition-all duration-300 group">
        <div className="relative h-48 bg-gradient-to-br from-gray-800 to-gray-900 flex items-center justify-center">
          {video.status === 'processed' && video.processed_url ? (
            isPlaying ? (
              <video
                className="w-full h-full object-cover"
                controls
                autoPlay
                onEnded={() => setIsPlaying(false)}
              >
                <source src={`http://localhost${video.processed_url}`} type="video/mp4" />
                Tu navegador no soporta el elemento de video.
              </video>
            ) : (
              <>
                <div className="absolute inset-0 bg-black/30"></div>
                <button
                  onClick={() => setIsPlaying(true)}
                  className="relative z-10 bg-white/90 backdrop-blur text-gray-900 px-6 py-3 rounded-full font-semibold transform hover:scale-110 transition-all shadow-lg"
                >
                  <Play className="inline mr-2" size={20} />
                  Reproducir Video
                </button>
              </>
            )
          ) : (
            <Video className="w-12 h-12 text-white opacity-50" />
          )}

          {video.status === 'processing' && (
            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center">
              <div className="text-center">
                <Loader2 className="w-8 h-8 text-white animate-spin mx-auto mb-2" />
                <span className="text-white text-sm">Procesando...</span>
              </div>
            </div>
          )}

          <div className="absolute top-2 right-2 bg-black/50 backdrop-blur text-white px-2 py-1 rounded-full text-xs">
            <Eye className="inline mr-1" size={12} />
            {Math.floor(Math.random() * 5000 + 1000)}
          </div>
        </div>

        <div className="p-4">
          <h4 className="font-bold text-lg text-gray-800 mb-1 truncate">{video.title}</h4>
          <div className="flex items-center justify-between text-sm text-gray-600 mb-3">
            <span>{video.user_first_name} {video.user_last_name}</span>
            <span className="bg-gray-100 px-2 py-0.5 rounded-full text-xs flex items-center">
              <MapPin className="w-3 h-3 mr-1" />
              {video.user_city}
            </span>
          </div>

          <div className="flex items-center justify-between">
            <div>
              <span className="text-2xl font-bold text-gray-800">{localVoteCount.toLocaleString()}</span>
              <span className="text-sm text-gray-500 ml-1">votos</span>
            </div>
            <div className="flex flex-col items-end">
              {voteError && (
                <div className="text-xs text-red-500 mb-1 text-right max-w-32">
                  {voteError}
                </div>
              )}
              <button
                onClick={handleVote}
                disabled={voted || isVoting || video.status !== 'processed' || !user}
                className={`px-4 py-2 rounded-full font-semibold transition-all transform ${voted
                    ? 'bg-green-500 text-white'
                    : isVoting
                      ? 'bg-orange-300 text-white cursor-not-allowed'
                      : video.status === 'processing'
                        ? 'bg-gray-200 text-gray-400 cursor-not-allowed'
                        : !user
                          ? 'bg-gray-200 text-gray-500 cursor-not-allowed'
                          : 'bg-gradient-to-r from-orange-500 to-red-500 text-white hover:shadow-lg hover:scale-105'
                  }`}
              >
                {voted ? (
                  <>
                    <CheckCircle className="inline mr-1" size={16} />
                    Votado
                  </>
                ) : isVoting ? (
                  <>
                    <Loader2 className="inline mr-1 animate-spin" size={16} />
                    Votando...
                  </>
                ) : video.status === 'processing' ? (
                  'Procesando...'
                ) : !user ? (
                  'Inicia sesión'
                ) : (
                  <>
                    <ThumbsUp className="inline mr-1" size={16} />
                    Votar
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  };

  // Renderizado principal
  return (
    <div className="min-h-screen bg-gray-50">
      <Navigation />
      {currentView === 'landing' && <LandingPage />}
      {currentView === 'login' && <LoginView />}
      {currentView === 'dashboard' && user && <Dashboard />}
      {currentView === 'upload' && user && <UploadVideoView
        selectedFile={selectedFile}
        setSelectedFile={setSelectedFile}
        videoTitle={videoTitle}
        setVideoTitle={setVideoTitle}
        uploading={uploading}
        setUploading={setUploading}
        dragActive={dragActive}
        setDragActive={setDragActive}
        uploadError={uploadError}
        setUploadError={setUploadError}
        videoIsPublic={videoIsPublic}
        setVideoIsPublic={setVideoIsPublic}
        processingStatus={processingStatus}
        setProcessingStatus={setProcessingStatus}
        uploadProgress={uploadProgress}
        setUploadProgress={setUploadProgress}
        resetUploadForm={resetUploadForm}
        apiService={apiService}
        setCurrentView={setCurrentView}
      />}
      {currentView === 'videos' && <VideosView />}
      {currentView === 'rankings' && <Rankings />}
      {currentView === 'profile' && user && <Profile />}
      {!user && currentView !== 'landing' && currentView !== 'login' && currentView !== 'rankings' && currentView !== 'videos' && (
        <div className="min-h-screen flex items-center justify-center">
          <div className="bg-white rounded-xl shadow-lg p-8 text-center max-w-md">
            <Shield className="w-16 h-16 mx-auto text-gray-400 mb-4" />
            <h3 className="text-xl font-semibold text-gray-800 mb-2">Acceso Restringido</h3>
            <p className="text-gray-600 mb-6">Debes iniciar sesión para acceder a esta sección</p>
            <button
              onClick={() => setCurrentView('login')}
              className="bg-gradient-to-r from-orange-500 to-red-500 text-white px-6 py-3 rounded-full font-bold hover:shadow-lg transform hover:scale-105 transition-all"
            >
              Iniciar Sesión
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;