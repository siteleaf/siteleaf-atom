SiteleafAtomView = require './siteleaf-atom-view'

module.exports =
  siteleafAtomView: null

  activate: (state) ->
    @siteleafAtomView = new SiteleafAtomView(state.siteleafAtomViewState)

  deactivate: ->
    @siteleafAtomView.destroy()

  serialize: ->
    siteleafAtomViewState: @siteleafAtomView.serialize()
