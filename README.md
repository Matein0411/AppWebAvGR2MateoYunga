# PoliMusic · WebApp con ASP 1.0

Aplicación musical con ASP Clásico (VBScript), SQL Server, HTML5, CSS y JavaScript. Incluye inicio de sesión, catálogo, reproducción de audio, canciones favoritas por usuario y gestión de canciones y álbumes para administradores.

La interfaz usa blanco y rojo, inspirada en Apple Music, con el menú a la izquierda y los recursos dentro de `assets/`.

## Captura de la aplicación

![Inicio de PoliMusic con interfaz blanca y roja](docs/screenshots/polimusic.png)

## Ejecutar

Antes del primer inicio, copia `webapppolimusicv1_asp/includes/config.example.asp` como `config.asp` en esa misma carpeta y completa tus credenciales locales. La configuración real y el SQL de referencia con contraseñas se conservan fuera de Git.

Configura `webapppolimusicv1_asp` como raíz de un sitio IIS con ASP Clásico, o inicia IIS Express desde PowerShell:

```powershell
.\webapppolimusicv1_asp\tools\start-local.ps1
```

Abre [PoliMusic local](http://localhost:8090/login.asp). La aplicación se conecta a la base existente `BDD_PoliMusic` en el puerto `14333`. **No ejecutes el SQL de referencia para iniciar la aplicación:** contiene instrucciones que recrean la base de datos.

Consulta la [documentación de instalación, estructura y funcionamiento](webapppolimusicv1_asp/README.md).

## Prompt de desarrollo

<details>
<summary>Ver el prompt original y los ajustes finales solicitados</summary>

### Rol

Actúa como un Desarrollador Web y Arquitecto de Software experto en HTML5, CSS3 moderno, JavaScript, ASP Clásico (VBScript) y bases de datos SQL Server.

### Contexto y Restricciones Tecnológicas

Debes desarrollar el código de una aplicación web tipo **clon de Spotify** para la gestión y reproducción de un catálogo de canciones, hazlo en el subdirectorio de webapppolimusicv1_asp.

- **Tecnología Obligatoria:** Todo el backend debe estar programado en **ASP Clásico con VBScript**.
- **Prohibición Absoluta:** NO utilizar ASP.NET, C#, ni frameworks modernos de backend. Todos los archivos dinámicos deben tener la extensión `.asp`.
- **Arquitectura:** Utiliza un diseño de pila centralizada. El código ASP debe ser limpio, directo a la base de datos y fácil de mantener.
- **Base de Datos:** SQL Server en un contenedor Docker (Puerto `14333`). El usuario y la contraseña se tomarán del script SQL de referencia que te proporcionaré.
- **REGLA DE ORO - Base de Datos:** El script SQL proporcionado es solo de referencia para entender el modelo entidad-relación. La base de datos ya está creada. **NO DEBES crear tablas adicionales, ni modificar el esquema**. Tu código solo debe realizar consultas (Select, Insert, Update, Delete) sobre las tablas existentes.

### Diseño y Experiencia de Usuario (UI/UX)

- **Concepto Visual:** Interfaz fluida, moderna e intuitiva inspirada en Spotify.
- **Paleta y Estética:** Diseño minimalista. Utiliza fondos blancos limpios para que el contenido respire, y emplea un color **azul suave (pastel)** basado en teoría del color para acentos, botones, bordes, cabeceras y controles del reproductor.
- **Pantallas Requeridas:**
  1. **Login (`login.asp`):** Pantalla de inicio de sesión estilizada, validando credenciales contra la base de datos.
  2. **Catálogo Principal:** La vista central de la aplicación. En la parte superior debe mostrar un mensaje de bienvenida con el nombre del usuario (leído obligatoriamente de la variable de sesión) y un botón integrado para **Cerrar Sesión (Logout)**.
- **Listado de Canciones:** **PROHIBIDO usar la etiqueta `<table>` HTML**. Implementa una disposición moderna usando CSS Grid o Flexbox (ej. formato de tarjetas o listas de reproducción interactivas).

### Lógica de Negocio y Funcionalidades

- **Control de Acceso y Roles:** Existen 2 roles (`normal` y `admin`). Valida la sesión en todas las páginas protegidas.
- **Permisos CRUD:**
  - **Admin:** Único rol que puede ver y ejecutar acciones para Crear, Editar o Eliminar canciones.
  - **Normal:** Solo puede visualizar el catálogo y reproducir la música.
- **Reproductor de Audio:** Integra un reproductor interactivo mediante JavaScript (etiqueta `<audio>`) integrado orgánicamente en el diseño pastel/blanco.
- **Rutas de Assets:**
  - Imágenes/Portadas: Carpeta `SongFilesAndImages_resources/`
  - Audio: Archivos `.mp3` ubicados en los assets correspondientes.

### Entregables Esperados

Por favor, entrégame el código estructurado de la siguiente manera:

1. **`login.asp`**: HTML/CSS del login + código VBScript para autenticar y crear las variables de sesión (`usuario` y `rol`).
2. **`logout.asp`**: Script corto en VBScript para destruir la sesión y redirigir al login.
3. **`index.asp`** (o `dashboard.asp`): Pantalla principal con el layout moderno (Grid/Flexbox), mensaje de bienvenida, reproductor de audio JS y visualización del catálogo.
4. **CRUD Admin**: Bloques de código VBScript (que pueden ir en la misma página o en páginas de procesamiento como `procesar.asp`) con las sentencias SQL nativas apuntando al puerto `14333`.
5. **CSS y JS**: El código de estilos y la lógica del reproductor (puedes entregarlos en archivos separados `style.css` y `app.js`, o incrustados si es más limpio).

### Ajustes finales solicitados

Estas indicaciones actualizan la paleta, los permisos y las rutas del prompt original:

- Cambiar la paleta a **rojo y blanco, estilo Apple Music**, manteniendo el menú a la izquierda.
- Añadir **gestión del catálogo de canciones y álbumes** para el administrador. Permitir elegir las canciones de un álbum y conservarlas en el catálogo al eliminarlo.
- Añadir **canciones favoritas por usuario**, en la sección **Mis me gusta**, usando las tablas existentes y sin modificar el esquema de la base de datos.
- Utilizar los archivos proporcionados en **`assets/`**, en lugar de `SongFilesAndImages_resources/`. Conservar las portadas anteriores de las canciones dentro de `assets/SongCovers/`.

</details>
