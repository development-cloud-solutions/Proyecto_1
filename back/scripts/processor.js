const fs = require('fs');
const path = require('path');
const FormData = require('form-data');
const http = require('http'); // Usar 'https' o 'http'

module.exports = {
  generateUniqueEmail: function(context, events, done) {
    // Generar un timestamp único
    const timestamp = Date.now();

    // Generar un número aleatorio
    const randomNum = Math.floor(Math.random() * 999999);

    // Generar un identificador único adicional
    const uniqueId = Math.random().toString(36).substring(2, 8);

    // Crear el email único usando datos del CSV si están disponibles
    const baseEmail = context.vars.email || 'loadtest@example.com';
    const emailPrefix = baseEmail.split('@')[0];
    const emailDomain = baseEmail.split('@')[1] || 'example.com';

    // Construir el email único
    context.vars.uniqueEmail = `${emailPrefix}_${timestamp}_${randomNum}_${uniqueId}@${emailDomain}`;

    // Generarvariantes del email para diferentes escenarios
    context.vars.uniqueEmailSignup = `signup_${timestamp}_${randomNum}@${emailDomain}`;
    context.vars.uniqueEmailAuth = `auth_${timestamp}_${randomNum}@${emailDomain}`;

    return done();
  },

  // Función auxiliar para generar datos aleatorios
  generateRandomData: function(context, events, done) {
    context.vars.randomFirstName = 'User' + Math.floor(Math.random() * 10000);
    context.vars.randomLastName = 'Test' + Math.floor(Math.random() * 1000);
    context.vars.randomCity = ['Bogotá', 'Medellín', 'Cali', 'Barranquilla', 'Cartagena'][Math.floor(Math.random() * 5)];
    return done();
  },

  uploadVideo: function (context, events, done) {
    const videoPath = path.resolve(__dirname, './../../docs/Video/Test_Video.mp4');

    // Verifica que el archivo existe
    if (!fs.existsSync(videoPath)) {
      console.error('Video file not found:', videoPath);
      context.vars.upload_status = 400;
      context.vars.upload_error = 'Video file not found';
      return done();
    }

    // Verificar token
    if (!context.vars.upload_token) {
      console.error('No upload token available');
      context.vars.upload_status = 401;
      context.vars.upload_error = 'No token available';
      return done();
    }

    const form = new FormData();
    form.append('video_file', fs.createReadStream(videoPath));
    form.append('title', `Load Test Video ${Math.floor(Math.random() * 10000)}`);
    form.append('is_public', 'true');

    const requestOptions = {
      method: 'POST',
      host: '3.227.188.83',
      port: 80,
      path: '/api/videos/upload',
      headers: {
        ...form.getHeaders(),
        Authorization: `Bearer ${context.vars.upload_token}`
      },
      timeout: 180000 // 3 minutos
    };

    const req = http.request(requestOptions, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const response = JSON.parse(data);
          context.vars.upload_status = res.statusCode;
          context.vars.upload_response = response;
          context.vars.video_task_id = response.task_id || null;
          context.vars.upload_message = response.message || null;

          if (res.statusCode === 201) {
            console.log(`Upload successful for token: ${context.vars.upload_token.substring(0, 20)}...`);
          } else {
            console.log(`Upload failed with status ${res.statusCode}: ${JSON.stringify(response)}`);
          }
        } catch (err) {
          context.vars.upload_status = res.statusCode;
          context.vars.upload_response = data;
          context.vars.upload_error = 'Invalid JSON response';
          console.error('JSON parse error:', err.message);
        }
        return done();
      });
    });

    req.on('error', (err) => {
      console.error('Upload request failed:', err.message);
      context.vars.upload_status = 0;
      context.vars.upload_error = err.message;
      return done(); 
    });

    req.on('timeout', () => {
      console.error('Upload request timed out');
      context.vars.upload_status = 0;
      context.vars.upload_error = 'Request timeout';
      req.abort(); // Abortar la petición
      req.destroy(); // Destruir el request
      return done();
    });

    // Configurar el pipe con cleanup automático
    const stream = form.pipe(req);

    // Añadir cleanup en caso de error
    stream.on('error', (err) => {
      console.error('Stream error:', err.message);
      req.abort();
      req.destroy();
    });
  }

};