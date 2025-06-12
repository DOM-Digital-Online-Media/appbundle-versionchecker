from flask import Flask, request, jsonify, render_template
import os, zipfile, tempfile, shutil, subprocess, plistlib

app = Flask(__name__)

UPLOAD_FOLDER = "/tmp/version_service_uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route('/')
def form():
    return render_template("upload.html")

@app.route('/upload/aab', methods=['POST'])
def upload_aab():
    file = request.files.get('aab')
    if not file:
        return jsonify(error="No AAB file provided"), 400

    with tempfile.TemporaryDirectory() as tmpdir:
        filepath = os.path.join(tmpdir, "app.aab")
        file.save(filepath)
        result = subprocess.run(
            ["/app/parse_aab.sh", filepath],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        if result.returncode != 0:
            return jsonify(error="Failed to parse AAB", details=result.stdout), 500

        return jsonify(parse_output(result.stdout))

@app.route('/upload/xcarchive', methods=['POST'])
def upload_xcarchive():
    file = request.files.get('xcarchive')
    if not file:
        return jsonify(error="No xcarchive ZIP file provided"), 400

    with tempfile.TemporaryDirectory() as tmpdir:
        zip_path = os.path.join(tmpdir, "archive.zip")
        file.save(zip_path)

        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(os.path.join(tmpdir, "archive"))

        archive_root = os.path.join(tmpdir, "archive")
        xcarchives = [os.path.join(archive_root, d) for d in os.listdir(archive_root) if d.endswith(".xcarchive")]
        if not xcarchives:
            return jsonify(error="No .xcarchive directory found in uploaded zip."), 400

        plist_path = os.path.join(xcarchives[0], "Info.plist")
        if not os.path.exists(plist_path):
            return jsonify(error="Info.plist not found in xcarchive."), 400

        with open(plist_path, "rb") as f:
            plist_data = plistlib.load(f)

        app_props = plist_data.get("ApplicationProperties", {})
        version_name = app_props.get("CFBundleShortVersionString")
        build_number = app_props.get("CFBundleVersion")
        signing_identity = app_props.get("SigningIdentity")
        team_id = app_props.get("Team")

        # Try to extract provisioning profile name from embedded.mobileprovision
        embedded_profile_path = os.path.join(xcarchives[0], "Products", "Applications")
        profile_name = "Not found"
        try:
            app_dirs = [d for d in os.listdir(embedded_profile_path) if d.endswith(".app")]
            if app_dirs:
                profile_path = os.path.join(embedded_profile_path, app_dirs[0], "embedded.mobileprovision")
                if os.path.exists(profile_path):
                    import re
                    with open(profile_path, "rb") as f:
                        data = f.read()
                    match = re.search(rb"<\?xml.*</plist>", data, re.DOTALL)
                    if match:
                        xml_data = match.group(0)
                        profile_plist = plistlib.loads(xml_data)
                        profile_name = profile_plist.get("Name", "Unknown")
                    else:
                        profile_name = "Could not parse embedded.mobileprovision"
        except Exception as e:
            profile_name = f"Error extracting profile name: {e}"
        provisioning_profile = profile_name

        if not version_name or not build_number:
            return jsonify(
                error="Failed to parse xcarchive",
                details=f"CFBundleShortVersionString or CFBundleVersion not found in ApplicationProperties. Full plist: {plist_data}"
            ), 500

        return jsonify({
            "versionName": version_name,
            "buildNumber": build_number,
            "signingIdentity": signing_identity,
            "teamId": team_id,
            "provisioningProfile": provisioning_profile
        })

# Example function to extract version info from Info.plist (not currently used)
def extract_xcarchive_version(plist_data):
    # ApplicationProperties is a nested dictionary inside Info.plist
    application_properties = plist_data.get("ApplicationProperties", {})
    version_name = application_properties.get("CFBundleShortVersionString")
    build_number = application_properties.get("CFBundleVersion")
    return version_name, build_number

def parse_output(output):
    result = {}
    for line in output.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            result[key.strip()] = value.strip()
    return result

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
