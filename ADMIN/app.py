from flask import Flask, render_template, redirect, url_for, request
import firebase_admin
from firebase_admin import credentials, db, firestore
import cloudinary.uploader 
from flask import jsonify
from datetime import datetime
from collections import defaultdict

app = Flask(__name__)
cred = credentials.Certificate('tastytalk-66621-firebase-adminsdk-fbsvc-dea310a8cb.json')

# Initialize Firebase app with the Realtime Database URL
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://tastytalk-66621-default-rtdb.firebaseio.com'
})
cloudinary.config(
    cloud_name='dhhvbvxsl',
    api_key='275288421299138',
    api_secret='XWFoqZWD__pHVqXG_EKSROvVoKY'
)

# Initialize Firestore client with a different variable name
firestore_db = firestore.client()

@app.route('/')
def index():
    return redirect(url_for('login')) 

@app.route('/login')
def login():
    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    # Count users from Realtime Database
    users_ref = db.reference('users')
    users_data = users_ref.get()
    num_users = len(users_data) if users_data else 0

    # Count dishes: exclude those with archived = true
    dishes_ref = firestore_db.collection('dishes')
    dishes_docs = dishes_ref.stream()

    num_dishes = 0
    for doc in dishes_docs:
        dish = doc.to_dict()
        if not dish.get('archived', False):
            num_dishes += 1

    # Gather feedback ratings grouped by day
    feedback_ref = firestore_db.collection('feedback')
    feedback_docs = feedback_ref.stream()

    day_ratings = defaultdict(list)
    for doc in feedback_docs:
        data = doc.to_dict()
        rating = data.get('rating')
        timestamp = data.get('timestamp')

        if rating and timestamp:
            # Convert Firestore timestamp to Python datetime if needed
            if hasattr(timestamp, 'to_datetime'):
                timestamp = timestamp.to_datetime()
            day = timestamp.strftime('%a')  # e.g. 'Mon', 'Tue'
            day_ratings[day].append(rating)

    # Calculate average rating per day
    feedback_labels = []
    feedback_ratings = []
    for day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']:
        ratings = day_ratings.get(day, [])
        avg = round(sum(ratings) / len(ratings), 2) if ratings else 0
        feedback_labels.append(day)
        feedback_ratings.append(avg)

    # Get recent admin activities from notifications
    admin_activities = []
    try:
        notifications_ref = firestore_db.collection('notifications')
        notifications_docs = list(notifications_ref.stream())
        
        # Sort all notifications by timestamp first
        all_notifications = []
        for doc in notifications_docs:
            notif = doc.to_dict()
            all_notifications.append(notif)
        
        all_notifications.sort(key=lambda x: x.get('timestamp', datetime.min), reverse=True)
        
        # Remove duplicates and get recent 6 activities
        selected_notifications = []
        seen_dishes = set()
        
        for notif in all_notifications:
            title = notif.get('title', '')
            message = notif.get('message', '')
            
            # Extract dish name
            dish_name = 'Unknown'
            if ':' in message:
                dish_name = message.split(':', 1)[1].strip()
            elif '"' in message:
                start = message.find('"') + 1
                end = message.find('"', start)
                if start > 0 and end > start:
                    dish_name = message[start:end]
            
            # Create unique key for this notification
            notif_key = f"{title}_{dish_name}"
            
            # Skip if we've already seen this exact notification
            if notif_key in seen_dishes:
                continue
            
            # Add notification (no type restrictions)
            selected_notifications.append(notif)
            seen_dishes.add(notif_key)
            
            # Stop if we have 6 notifications
            if len(selected_notifications) >= 6:
                break
        
        for notif in selected_notifications[:6]:  # Max 6 total
            timestamp = notif.get('timestamp')
            if hasattr(timestamp, 'to_datetime'):
                timestamp = timestamp.to_datetime()
            if hasattr(timestamp, 'replace'):
                timestamp = timestamp.replace(tzinfo=None)
            
            # Calculate time ago
            time_diff = datetime.now() - timestamp
            if time_diff.days > 0:
                time_ago = f"{time_diff.days} day{'s' if time_diff.days > 1 else ''} ago"
            elif time_diff.seconds > 3600:
                hours = time_diff.seconds // 3600
                time_ago = f"{hours} hour{'s' if hours > 1 else ''} ago"
            else:
                minutes = max(1, time_diff.seconds // 60)
                time_ago = f"{minutes} minute{'s' if minutes > 1 else ''} ago"
            
            # Get dish name and determine action
            title = notif.get('title', '')
            message = notif.get('message', '')
            
            dish_name = 'Unknown dish'
            if ':' in message:
                dish_name = message.split(':', 1)[1].strip()
            elif '"' in message:
                start = message.find('"') + 1
                end = message.find('"', start)
                if start > 0 and end > start:
                    dish_name = message[start:end]
            
            # Determine action based on title
            if 'Updated' in title:
                icon = '✏️'
                action_text = f"Updated dish: {dish_name}"
            elif 'Added' in title:
                icon = '➕'
                action_text = f"Added dish: {dish_name}"
            else:
                icon = '📢'
                action_text = title or 'Other notification'
            
            admin_activities.append({
                'icon': icon,
                'action': action_text,
                'timestamp': time_ago
            })
                
    except Exception as e:
        print(f"Error fetching admin activities: {e}")
        admin_activities = []

    return render_template(
        'dashboard.html',
        num_users=num_users,
        num_dishes=num_dishes,
        feedback_labels=feedback_labels,
        feedback_ratings=feedback_ratings,
        admin_activities=admin_activities
    )



@app.route('/add_dish')
def add_dish():
    return render_template('add_dish.html')

@app.route('/manage_dish')
def manage_dish():
    selected_category = request.args.get('category')
    
    dishes_ref = firestore_db.collection('dishes')
    docs = dishes_ref.stream()

    dishes = []
    archived_dishes = []

    for doc in docs:
        dish_data = doc.to_dict()
        dish = {
            'id': doc.id,
            'name': dish_data.get('name', ''),
            'category': dish_data.get('category', ''),
            'servings': dish_data.get('servings', ''),
            'duration': dish_data.get('duration', ''),
            'ingredients': dish_data.get('ingredients', []),
            'procedures': dish_data.get('procedures', []),
            'rating': dish_data.get('rating', 0),
            'imageUrl': dish_data.get('imageUrl', ''),
            'source': dish_data.get('source', '')  
        }

        if dish_data.get('archived', False):
            archived_dishes.append(dish)
        else:
            if not selected_category or dish_data.get('category') == selected_category:
                dishes.append(dish)

    return render_template(
        'manage_dish.html',
        dishes=dishes,
        archived_dishes=archived_dishes,
        selected_category=selected_category
    )


@app.route('/update_dish/<dish_id>', methods=['POST'])
def update_dish(dish_id):
    updated = {
        'name': request.form['name'].strip(),
        'servings': int(request.form['servings']),
        'duration': request.form['duration'].strip(),
        'category': request.form['category'].strip(),
        'source': request.form['source'].strip()   
    }

    # INGREDIENTS
    quantities = request.form.getlist('ingredient_quantity[]')
    units = request.form.getlist('ingredient_unit[]')
    names = request.form.getlist('ingredient_name[]')
    substitutes_raw = request.form.getlist('ingredient_subs[]')

    ingredients = []
    for i in range(len(names)):
        if names[i].strip():
            ingredients.append({
                'quantity': quantities[i].strip(),
                'unit': units[i].strip(),
                'name': names[i].strip(),
                'substitutes': [s.strip() for s in substitutes_raw[i].split(',') if s.strip()]
            })
    updated['ingredients'] = ingredients

    # PROCEDURES
    procedures = [step.strip() for step in request.form.getlist('procedures[]') if step.strip()]
    updated['procedures'] = procedures

    # IMAGE
    image_file = request.files.get('image')
    if image_file and image_file.filename:
        upload_result = cloudinary.uploader.upload(image_file, folder="tasty_talk/dishes")
        updated['imageUrl'] = upload_result['secure_url']

    # UPDATE DISH IN FIRESTORE
    firestore_db.collection('dishes').document(dish_id).update(updated)
    
    # CREATE NOTIFICATION FOR ALL USERS (OPTIMIZED)
    try:
        # Get all users from Realtime Database
        users_ref = db.reference('users')
        users_data = users_ref.get()
        
        if users_data:
            # Use batch write for better performance
            batch = firestore_db.batch()
            
            # Create base notification data
            base_notification = {
                'title': 'Recipe Updated!',
                'message': f'The recipe "{updated["name"]}" has been updated with new improvements.',
                'dishId': dish_id,
                'dishName': updated['name'],
                'timestamp': datetime.now(),
                'type': 'recipe_update',
                'read': False
            }
            
            # Add notifications in batches (Firestore limit is 500 per batch)
            user_ids = list(users_data.keys())
            for i in range(0, len(user_ids), 500):
                batch = firestore_db.batch()
                batch_users = user_ids[i:i+500]
                
                for user_id in batch_users:
                    doc_ref = firestore_db.collection('notifications').document()
                    notification_data = base_notification.copy()
                    notification_data['userId'] = user_id
                    batch.set(doc_ref, notification_data)
                
                batch.commit()
                
        print(f"Notifications sent for updated dish: {updated['name']}")
    except Exception as e:
        print(f"Error sending notifications: {e}")

    return redirect(url_for('manage_dish'))



@app.route('/archive_dish/<dish_id>', methods=['POST'])
def archive_dish(dish_id):
    try:
        print(f"Archiving dish ID: {dish_id}")  
        dish_ref = firestore_db.collection('dishes').document(dish_id)
        dish_ref.update({'archived': True})
        print("Update successful.")  
        return redirect('/manage_dish')
    except Exception as e:
        print(f"Error archiving dish: {e}")
        return redirect('/manage_dish')

@app.route('/unarchive_dish/<dish_id>', methods=['POST'])
def unarchive_dish(dish_id):
    try:
        # Get the document reference for the specific dish in Firestore
        dish_ref = firestore_db.collection('dishes').document(dish_id)

        # Update the archived field to False (0)
        dish_ref.update({'archived': False})

        return redirect('/manage_dish')
    except Exception as e:
        print(f"Error unarchiving dish: {e}")
        return redirect('/manage_dish')




@app.route('/manage_users')
def manage_users():
    # Reference to the users node in Realtime Database
    users_ref = db.reference('users')
    users_data = users_ref.get()

    # Get feedback data to calculate cooking levels
    feedback_ref = firestore_db.collection('feedback')
    feedback_docs = feedback_ref.stream()
    
    user_ratings = {}
    for doc in feedback_docs:
        data = doc.to_dict()
        user_id = data.get('userId')
        rating = data.get('rating')
        if user_id and rating:
            if user_id not in user_ratings:
                user_ratings[user_id] = []
            user_ratings[user_id].append(rating)

    users_list = []
    if users_data:
        for key, user_data in users_data.items():
            # Calculate average rating for cooking level
            ratings = user_ratings.get(key, [])
            avg_rating = round(sum(ratings) / len(ratings), 1) if ratings else 0
            
            # Determine cooking level based on average rating (matching mobile app)
            if avg_rating >= 4.5:
                cooking_level = "A Cook"
            elif avg_rating >= 3.5:
                cooking_level = "Better"
            elif avg_rating >= 2.0:
                cooking_level = "Good"
            elif avg_rating > 0:
                cooking_level = "Not Good"
            else:
                cooking_level = "No Ratings"
            
            users_list.append({
                'uid': key,
                'fullName': user_data.get('fullName', 'N/A'),
                'birthday': user_data.get('birthday', 'N/A'),
                'age': user_data.get('age', 'N/A'),
                'gender': user_data.get('gender', 'N/A'),
                'username': user_data.get('username', 'N/A'),
                'email': user_data.get('email', 'N/A'),
                'cookingLevel': cooking_level,
                'avgRating': avg_rating
            })
    
    # Sort users alphabetically by fullName
    users_list.sort(key=lambda x: x['fullName'].lower())

    return render_template('manage_users.html', users=users_list)

@app.route('/edit_user', methods=['POST'])
def edit_user():
    try:
        uid = request.form['uid']
        full_name = request.form['fullName'].strip()
        birthday = request.form['birthday']
        age = int(request.form['age'])
        gender = request.form['gender']
        username = request.form['username'].strip()
        email = request.form['email'].strip()
        
        # Update user data in Realtime Database
        users_ref = db.reference('users')
        user_data = {
            'fullName': full_name,
            'birthday': birthday,
            'age': age,
            'gender': gender,
            'username': username,
            'email': email
        }
        
        users_ref.child(uid).update(user_data)
        
        return redirect(url_for('manage_users'))
        
    except Exception as e:
        print(f"Error updating user: {e}")
        return redirect(url_for('manage_users'))

@app.route('/logout')
def logout():
    return redirect(url_for('login'))

if __name__ == '__main__':
    app.run(debug=True)
