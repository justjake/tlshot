console.log("image decoder worker loaded");
self.onmessage = async (ev) => {
  const imageData = ev.data as ArrayBuffer;
  console.log("work on", imageData, "in worker");
  // const imageResponse = await fetch(urlString);
  // const imageData = await imageResponse.blob();
  console.log("fetched", imageData);
  const imageBitmap = await createImageBitmap(new Blob([imageData]), {
    // Resizing isn't happening here.
    // resizeHeight: 100,
    // resizeWidth: 100,
    // resizeQuality: "pixelated",
  });
  console.log("created", imageBitmap);
  self.postMessage(imageBitmap, [imageBitmap]);
};
