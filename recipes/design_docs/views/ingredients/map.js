function(doc) {
  if (doc.ingredients && doc.ingredients.length > 0) {
    doc.ingredients.forEach(function(item) {
      if (item.ingredient) {
        emit(item.ingredient, item.measure);
      }
    });
  }
}
