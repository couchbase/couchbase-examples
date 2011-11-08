function(doc) {
  if (doc.keywords && doc.keywords.length > 0) {
    doc.keywords.forEach(function(keyword) {
      emit(keyword.split('@'), 1)
    });
  }
}
