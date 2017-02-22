from flask import Flask, render_template, request, jsonify

# Initialize the Flask application
app = Flask(__name__)

@app.route('/')
def index():
    # Render template
    return render_template('index.html')

@app.route('/post', methods = ['POST'])
def post():
    # Get the parsed contents of the form data
    json = request.json
    print(json)
    # Render template
    return jsonify(json)

if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True)