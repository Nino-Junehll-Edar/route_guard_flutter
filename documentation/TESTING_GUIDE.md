# RouteGuard Testing Guide

## Preparing Supabase for Deployment

### 1. Apply Database Schema
1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of `supabase/schema.sql`
4. Click "Run" to apply the schema

### 2. Set Up Storage
1. Go to Storage in your Supabase dashboard
2. Create a new bucket called `hazard-photos` (make it public)
3. Optionally enable file size limits and allowed MIME types (image/jpeg, image/png)

### 3. Deploy Edge Functions
1. Install Supabase CLI if you haven't: `npm install -g supabase`
2. Login to Supabase: `supabase login`
3. Link your project: `supabase link --project-ref YOUR_PROJECT_REF`
4. Deploy functions: `supabase functions deploy --project-ref YOUR_PROJECT_REF`

### 4. Set Environment Variables for Edge Functions
In your Supabase dashboard:
1. Go to Settings → Edge Functions → Environment Variables
2. Add:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_SERVICE_ROLE_KEY`: Your service role key (found in Settings → API)

## Testing on Android Device

### Prerequisites
- Android Studio or VS Code with Flutter/Android plugins
- Android device or emulator
- Flutter installed and configured

### Steps
1. Connect your Android device via USB or start an emulator
2. Enable USB debugging on your device (Settings → Developer options)
3. Run `flutter devices` to verify device is recognized
4. Run the app: `flutter run`
5. For release builds: `flutter build apk` or `flutter build appbundle`

### Testing Specific Features
- **Authentication**: Test login/signup with test accounts
- **Hazard Reporting**: 
  - Allow location permissions when prompted
  - Try reporting a hazard with/without photo
  - Check if it appears on the map (may need to wait for realtime updates)
- **Profile**: Check reputation and level display
- **Notifications**: Walk near a reported hazard to test proximity alerts
- **Offline Functionality**: 
  - Turn off internet, try reporting a hazard
  - Turn internet back on, check if it syncs
- **Performance**: Check console logs for performance metrics (tagged with "PerformanceMonitoring")

## Testing on Web

### Prerequisites
- Web browser (Chrome, Firefox, Safari, Edge)
- Firebase hosting already configured for the web app

### Steps
1. Build for web: `flutter build web`
2. The built files will be in `build/web/`
3. Firebase hosting should automatically serve these when deployed
4. Or test locally: `firebase serve --only hosting`

### Testing Specific Features
- Same as Android, but use mouse/touchpad instead of touch
- Test responsive design at different window sizes
- Check browser console for errors and performance logs

## Common Testing Scenarios

### User Flow Testing
1. New user signs up
2. User logs in
3. User reports a hazard
4. Hazard appears on map for all users
5. Other users can confirm/deny the hazard
6. Hazard status updates based on votes
7. User gains/loses reputation based on accuracy
8. Proximity notifications work when near hazards
9. Agency users can post official advisories

### Edge Case Testing
1. Report hazard with no photo
2. Report hazard with very long description
3. Try to update hazard you didn't create (should fail)
4. Try to update profile you don't own (should fail)
5. Network interrupted during hazard submission
6. Low confidence hazards over time should decay
7. Very old hazards should eventually become "clear"

### Security Testing
1. Try accessing another user's profile data (should fail)
2. Try updating another user's hazard (should fail)
3. Non-agency user trying to post official advisory (should fail)
4. Check that RLS policies are working by testing with different users

## Performance Monitoring
The app includes performance monitoring that logs to the console. Look for tags like:
- "PerformanceMonitoring: GetCurrentPosition took XXXms"
- "PerformanceMonitoring: UploadHazardPhoto took XXXms"
- etc.

These can help identify bottlenecks during testing.

## Troubleshooting

### Common Issues
1. **MissingPluginException**: Make sure all plugins are installed (`flutter pub get`)
2. **Supabase initialization errors**: Check your supabase_options.dart URL and anon key
3. **Storage permission errors**: Make sure the hazard-photos bucket exists and is public
4. **CORS issues on web**: Ensure your Supabase project has correct CORS settings
5. **Edge function errors**: Check function logs in Supabase dashboard

### Getting Logs
- **Android**: Use `adb logcat` or Android Studio's Logcat
- **Web**: Use browser developer tools console
- **iOS**: Use Xcode console or `idevicesyslog`

## Release Checklist
Before releasing:
1. [ ] All tests pass (`flutter test`)
2. [ ] Schema applied to Supabase with proper RLS
3. [ ] Edge functions deployed and tested
4. [ ] Storage bucket configured correctly
5. [ ] Firebase hosting set up for web (if applicable)
6. [ ] Android/iOS build credentials configured
7. [ ] Performance monitoring working
8. [ ] Offline sync functioning correctly
9. [ ] Proximity notifications tested
10. [ ] Agency workflow tested