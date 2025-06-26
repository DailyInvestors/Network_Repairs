import React, { useState } from "react";
import axios from "axios";

function UploadFunctionComponent() {
  const [file, setFile] = useState(null);
  const [response, setResponse] = useState(null);

  const handleFileChange = (e) => {
    setFile(e.target.files[0]);
  };

  const handleUpload = async () => {
    if (!file) return;

    const formData = new FormData();
    formData.append("file", file); // or "function" if your API expects that key

    try {
      const res = await axios.post("https://api.example.com/upload", formData, {
        headers: {
          "Content-Type": "multipart/form-data",
          "Authorization": "Bearer YOUR_API_KEY", // if needed
        },
      });
      setResponse(res.data);
    } catch (error) {
      setResponse(error.message);
    }
  };

  return (
    <div>
      <input type="file" onChange={handleFileChange} />
      <button onClick={handleUpload}>Upload Function</button>
      {response && <pre>{JSON.stringify(response, null, 2)}</pre>}
    </div>
  );
}

export default UploadFunctionComponent;
