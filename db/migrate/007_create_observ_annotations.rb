class CreateObservAnnotations < ActiveRecord::Migration[8.0]
  def change
    create_table :observ_annotations do |t|
      t.references :annotatable, polymorphic: true, null: false, index: true
      t.text :content, null: false
      t.string :annotator
      t.text :tags

      t.timestamps
    end
  end
end
