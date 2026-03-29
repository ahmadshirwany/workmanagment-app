# Firebase Hosting Deployment

## Quick Deploy to Firebase (Recommended - FREE)

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

2. Login to Firebase:
```bash
firebase login
```

3. Initialize Firebase in your project:
```bash
cd "d:\work\workmanagment app"
firebase init hosting
```
- Select: Use an existing project or create new
- Public directory: `build/web`
- Single-page app: Yes
- Overwrite index.html: No

4. Deploy:
```bash
firebase deploy --only hosting
```

You'll get a permanent URL like: `https://your-app.web.app`

---

## Alternative: GitHub Pages (FREE)

1. Create a GitHub repository
2. Push your code
3. Go to Settings > Pages
4. Select source: `build/web` folder
5. Your app will be at: `https://yourusername.github.io/repo-name`

---

## Alternative: Netlify Drop (Easiest - FREE)

1. Go to: https://app.netlify.com/drop
2. Drag and drop the `build\web` folder
3. Get instant URL like: `https://random-name.netlify.app`

---

Once deployed online, the PWA will work FOREVER on your phone, even offline!
